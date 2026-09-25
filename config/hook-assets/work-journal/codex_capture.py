#!/usr/bin/env python3
"""Capture explicit Codex session/call identity without guessing Atuin joins."""
import argparse
import json
import os
from pathlib import Path
import shlex
import sys
from urllib.parse import urlparse, unquote
import journal as j

FIELDS = ('codex_session_id', 'codex_turn_id', 'tool_use_id', 'tool_name',
          'phase', 'tool_input', 'tool_response', 'transcript_path', 'linkage',
          'atuin_session_id')

def required_text(payload, key):
    value = payload.get(key)
    if not isinstance(value, str) or not value:
        raise ValueError('Missing Codex identity field: ' + key)
    return value

def outcome(response):
    # Never infer command success from output prose or a completed tool-call marker.
    if isinstance(response, dict):
        code = response.get('exit_code')
        if type(code) is int and code >= 0:
            return ('success' if code == 0 else 'failure'), code
        if response.get('isError') is True:
            return 'failure', None
    return 'unknown', None

def capture(c, payload, *, occurred_at=None, source_ref=None, atuin_session=None):
    phase = {'PreToolUse':'started', 'PostToolUse':'returned',
             'PostToolUseFailure':'failed'}.get(payload.get('hook_event_name'))
    if phase is None:
        raise ValueError('Unsupported hook event')
    sid = required_text(payload, 'session_id')
    call = required_text(payload, 'tool_use_id')
    tool = required_text(payload, 'tool_name')
    cwd = required_text(payload, 'cwd')
    if j.within(cwd, str(j.ROOT / '.data')):
        return 0
    # Distinct lifecycle records keep late pre-events from overwriting a result.
    eid = 'codex:' + sid + ':' + call + ':' + phase
    receipt = j.digest(dict(payload=payload, occurred_at=occurred_at, source_ref=source_ref))
    c.execute('CREATE TABLE IF NOT EXISTS codex_receipts (id TEXT PRIMARY KEY)')
    c.commit()
    # Serialize duplicate receipt check and insertion across simultaneous hooks.
    c.execute('BEGIN IMMEDIATE')
    try:
        if c.execute('SELECT 1 FROM codex_receipts WHERE id=?', (receipt,)).fetchone():
            c.rollback()
            return 0
        inp = payload.get('tool_input', {})
        action = inp.get('command') if isinstance(inp,dict) else inp
        if not isinstance(action,str):
            action = j.canonical(inp)
        result, code = outcome(payload.get('tool_response'))
        if phase == 'started': result, code = 'unknown', None
        if phase == 'failed': result = 'failure'
        event = dict(event_id=eid, source='codex', occurred_at=occurred_at or j.now(),
            project=cwd, action=action, outcome=result, codex_session_id=sid,
            codex_turn_id=payload.get('turn_id'), tool_use_id=call, tool_name=tool,
            phase=phase, tool_input=inp, transcript_path=payload.get('transcript_path'),
            linkage='explicit_codex_ids', source_ref=source_ref or 'codex-hook:' + receipt,
            author='codex')
        if phase != 'started': event['tool_response'] = payload.get('tool_response')
        if code is not None: event['exit_code'] = code
        if atuin_session: event['atuin_session_id'] = atuin_session
        record = j.event_record(event)
        count = j.put(c, record)
        previous = c.execute('SELECT r.body FROM records r JOIN current_events e ON e.record_id=r.id WHERE e.event_id=?',(eid,)).fetchone()
        # Preserve a structured result if a delayed text-only hook arrives later.
        prior = json.loads(previous[0]) if previous else {}
        if not (prior.get('exit_code') is not None and record.get('exit_code') is None):
            c.execute('INSERT INTO current_events VALUES(?,?) ON CONFLICT(event_id) DO UPDATE SET record_id=excluded.record_id', (eid,record['id']))
        c.execute('INSERT INTO codex_receipts VALUES(?)', (receipt,))
        c.commit()
        return int(count)
    except Exception:
        c.rollback()
        raise

def transcript(c, path):
    path = Path(path).expanduser().resolve()
    sid = cwd = turn = None
    calls = {}
    added = 0
    unmatched = 0
    # Replay a single explicit source; incomplete final lines are retried next pass.
    with path.open() as stream:
        for n,line in enumerate(stream,1):
            if not line.endswith('\n'): break
            try:
                row = json.loads(line)
            except ValueError as exc:
                raise ValueError(f'{path}:{n}: malformed transcript JSON') from exc
            p = row.get('payload',{})
            if row.get('type') == 'session_meta':
                sid,cwd = p.get('id'),p.get('cwd')
            elif row.get('type') == 'turn_context':
                turn = p.get('turn_id')
                cwd = p.get('cwd',cwd)
            elif row.get('type') == 'event_msg' and p.get('type') == 'item_completed':
                item = p.get('item', {})
                if item.get('type') == 'CommandExecution':
                    command = item.get('command', [])
                    directory = item.get('cwd', cwd)
                    if isinstance(directory,str) and directory.startswith('file:'):
                        directory = unquote(urlparse(directory).path)
                    payload = dict(session_id=p.get('thread_id') or sid,
                        turn_id=p.get('turn_id'),tool_use_id=item.get('id'),tool_name='Bash',
                        cwd=directory,transcript_path=str(path),hook_event_name='PostToolUse',
                        tool_input={'command':command[-1] if isinstance(command,list) and command else command},
                        tool_response={k:item[k] for k in ('exit_code','stdout','stderr','status') if k in item})
                    added += capture(c,payload,occurred_at=row['timestamp'],source_ref=f'{path}:{n}')
            elif row.get('type') == 'response_item':
                kind = p.get('type')
                if kind in ('function_call','custom_tool_call'):
                    if not sid or not cwd: raise ValueError('Call precedes session metadata')
                    inp = p.get('arguments') if kind == 'function_call' else p.get('input')
                    if kind == 'function_call' and isinstance(inp,str):
                        try: inp=json.loads(inp)
                        except ValueError: pass
                    payload = dict(session_id=sid,turn_id=turn,tool_use_id=p.get('call_id'),
                        tool_name=p.get('name'),tool_input=inp,cwd=cwd,
                        transcript_path=str(path),hook_event_name='PreToolUse')
                    calls[p.get('call_id')] = payload
                    added += capture(c,payload,occurred_at=row['timestamp'],source_ref=f'{path}:{n}')
                elif kind in ('function_call_output','custom_tool_call_output'):
                    payload = calls.get(p.get('call_id'))
                    if payload is None:
                        unmatched += 1
                        continue
                    response=p.get('output')
                    if isinstance(response,str):
                        try: response=json.loads(response)
                        except ValueError: pass
                    added += capture(c,dict(payload,hook_event_name='PostToolUse',tool_response=response),
                                     occurred_at=row['timestamp'],source_ref=f'{path}:{n}')
    return dict(revisions_added=added, codex_session_id=sid, calls=len(calls), unmatched_outputs=unmatched)

def config(existing, receiver, python):
    # Deep copy preserves unrelated hook definitions; install is idempotent.
    result=json.loads(json.dumps(existing))
    hooks=result.setdefault('hooks',{})
    command=shlex.join([str(python),str(receiver),'hook'])
    for event in ('PreToolUse','PostToolUse'):
        group={'matcher':'*','hooks':[{'type':'command','command':command,'timeout':5}]}
        entries=hooks.setdefault(event,[])
        if group not in entries: entries.append(group)
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--db',default=str(j.DEFAULT_DB))
    sub=parser.add_subparsers(dest='command',required=True)
    sub.add_parser('hook')
    p=sub.add_parser('transcript');p.add_argument('path')
    p=sub.add_parser('prepare-hooks');p.add_argument('existing');p.add_argument('output')
    args=parser.parse_args()
    os.umask(0o077)
    if args.command=='prepare-hooks':
        original=json.loads(Path(args.existing).read_text())
        proposed=config(original,Path(__file__).resolve(),sys.executable)
        Path(args.output).write_text(json.dumps(proposed,indent=2)+'\n')
        return
    with j.connect(args.db, timeout=1 if args.command=='hook' else 15) as c:
        if args.command=='hook':
            capture(c,json.load(sys.stdin),atuin_session=os.environ.get('ATUIN_SESSION'))
            # Hook stdout must not inject a summary into the active conversation.
        else:
            j.emit(transcript(c,args.path))

if __name__=='__main__':
    try: main()
    except Exception as exc:
        print('work-journal capture: '+str(exc),file=sys.stderr)
        sys.exit(1)
