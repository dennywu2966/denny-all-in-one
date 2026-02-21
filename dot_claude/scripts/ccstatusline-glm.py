#!/usr/bin/env python3
"""
ccstatusline replacement for GLM models with nord-aurora powerline theme.
Matches exact ccstatusline output format but fixes GLM token counts.
"""

import json
import sys
import os
import subprocess
import re

# Powerline separator
POWERLINE_SEPARATOR = '\uE0B0'

# Nord-Aurora theme colors (ansi256 level)
NORD_AURORA = {
    'fg': [231, 16, 231, 16, 16],
    'bg': [131, 220, 68, 108, 176]
}

def get_git_branch():
    """Get current git branch name."""
    try:
        result = subprocess.run(
            ['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
            capture_output=True,
            text=True,
            timeout=100,
            cwd=os.getcwd()
        )
        if result.returncode == 0:
            branch = result.stdout.strip()
            return branch if branch and branch != 'HEAD' else None
    except:
        pass
    return None

def estimate_tokens_from_transcript(transcript_path: str) -> dict:
    """Estimate tokens from transcript file for GLM models."""
    # Try the provided path first
    if transcript_path and os.path.exists(transcript_path):
        return _estimate_from_file(transcript_path)

    # Fall back to history.jsonl if provided path doesn't exist
    history_path = os.path.expanduser('~/.claude/history.jsonl')
    if os.path.exists(history_path):
        return _estimate_from_file(history_path)

    return {'context_length': 0, 'total_tokens': 0, 'has_real': False}

def _estimate_from_file(transcript_path: str) -> dict:
    """Estimate tokens from a specific transcript file."""

    total_chars = 0
    chinese_chars = 0
    max_input_tokens = 0
    total_output_tokens = 0
    has_real = False

    try:
        with open(transcript_path, 'r', encoding='utf-8') as f:
            for line in f:
                try:
                    data = json.loads(line)
                    msg = data.get('message', {})
                    usage = msg.get('usage', {})

                    # Track maximum input tokens (context window)
                    input_tokens = usage.get('input_tokens', 0)
                    if input_tokens > 0:
                        max_input_tokens = max(max_input_tokens, input_tokens)
                        total_output_tokens += usage.get('output_tokens', 0)
                        has_real = True

                    # Count characters for estimation (in case we need fallback)
                    total_chars += len(line)
                    chinese_chars += len(re.findall(r'[\u4e00-\u9fff]', line))
                except:
                    continue

        # If we found real tokens, use them
        if has_real and max_input_tokens > 0:
            return {
                'context_length': max_input_tokens,
                'total_tokens': max_input_tokens + total_output_tokens,
                'has_real': True
            }

        # Estimate: Chinese ~1.5 chars/token, English ~4 chars/token
        non_chinese = total_chars - chinese_chars
        estimated_tokens = int((chinese_chars / 1.5) + (non_chinese / 4))

        # Context is ~30% of total
        context_length = min(int(estimated_tokens * 0.3), 200000)

        return {
            'context_length': context_length,
            'total_tokens': estimated_tokens,
            'has_real': False
        }
    except:
        return {'context_length': 0, 'total_tokens': 0, 'has_real': False}

def powerline_widget(text: str, widget_idx: int, total_widgets: int, next_bg: int = None):
    """Render a widget with powerline formatting matching ccstatusline exactly."""
    fg = NORD_AURORA['fg'][widget_idx % len(NORD_AURORA['fg'])]
    bg = NORD_AURORA['bg'][widget_idx % len(NORD_AURORA['bg'])]

    parts = []

    # Widget content: fg + bg + text + reset
    parts.append(f'\x1b[38;5;{fg}m')
    parts.append(f'\x1b[48;5;{bg}m')
    parts.append(f' {text} ')
    parts.append('\x1b[49m')  # reset bg
    parts.append('\x1b[39m')  # reset fg

    # Separator if not last
    if widget_idx < total_widgets - 1:
        next_bg_color = next_bg if next_bg is not None else NORD_AURORA['bg'][(widget_idx + 1) % len(NORD_AURORA['bg'])]
        parts.append(f'\x1b[38;5;{bg}m')  # separator fg = current bg
        parts.append(f'\x1b[48;5;{next_bg_color}m')  # separator bg = next bg
        parts.append(POWERLINE_SEPARATOR)
        parts.append('\x1b[0m')  # reset
        parts.append('\x1b[39m')  # reset fg

    return ''.join(parts)

def get_agent_dir(session_id: str) -> str:
    """Get agent working directory from session ID."""
    if not session_id:
        return None

    # First try to find the agent's transcript and extract cwd from it
    agent_cwd = _get_agent_cwd_from_transcript(session_id)
    if agent_cwd:
        return agent_cwd

    # Fallback: check if it's a running agent task (deprecated)
    try:
        tasks_dir = os.path.expanduser('~/.claude/tasks')
        agent_dir = os.path.join(tasks_dir, session_id)
        if os.path.exists(agent_dir):
            # This is a task directory, not the working directory
            # Return None to indicate no specific agent cwd
            return None
    except:
        pass
    return None

def _get_agent_cwd_from_transcript(session_id: str) -> str:
    """Extract the most recent working directory from agent's transcript."""
    if not session_id:
        return None

    transcript_path = None

    # Try to find the agent's transcript file
    for base_dir in ['~/.claude/projects', '~/.claude/sessions']:
        search_path = os.path.expanduser(base_dir)
        if os.path.exists(search_path):
            for root, dirs, files in os.walk(search_path):
                if f'{session_id}.jsonl' in files:
                    transcript_path = os.path.join(root, f'{session_id}.jsonl')
                    break
            if transcript_path:
                break

    if not transcript_path or not os.path.exists(transcript_path):
        return None

    # Read the transcript and find the most recent cwd
    most_recent_cwd = None
    try:
        with open(transcript_path, 'r', encoding='utf-8') as f:
            for line in f:
                try:
                    data = json.loads(line)
                    cwd = data.get('cwd')
                    if cwd:
                        most_recent_cwd = cwd
                except:
                    continue
    except:
        pass

    return most_recent_cwd

def shorten_path(path: str, max_len: int = 40) -> str:
    """Shorten path for display while keeping important parts."""
    if len(path) <= max_len:
        return path
    # Replace home dir with ~
    home = os.path.expanduser('~')
    if path.startswith(home):
        path = '~' + path[len(home):]
    if len(path) <= max_len:
        return path
    # Truncate middle: keep start and end
    parts = path.split(os.sep)
    if len(parts) <= 2:
        return path
    # Keep first part and last 2 parts
    return os.sep.join([parts[0], '...', parts[-2], parts[-1]])

def get_transcript_path(session_id: str, cwd: str) -> str:
    """Get the transcript path from session_id and working directory."""
    if not session_id:
        return None

    # Try project-specific transcript first
    project_dir = cwd.replace('/', '-', 1).replace('_', '-')
    if project_dir.startswith('-'):
        project_dir = project_dir[1:]

    project_path = os.path.expanduser(f'~/.claude/projects/{project_dir}/{session_id}.jsonl')
    if os.path.exists(project_path):
        return project_path

    # Try session ID directly in projects
    for base_dir in ['~/.claude/projects', '~/.claude/sessions']:
        search_path = os.path.expanduser(base_dir)
        if os.path.exists(search_path):
            for root, dirs, files in os.walk(search_path):
                if f'{session_id}.jsonl' in files:
                    return os.path.join(root, f'{session_id}.jsonl')

    # Fall back to history.jsonl
    history_path = os.path.expanduser('~/.claude/history.jsonl')
    if os.path.exists(history_path):
        return history_path

    return None

def main():
    try:
        stdin_data = sys.stdin.read()
        data = json.loads(stdin_data) if stdin_data else {}

        # Extract data
        transcript_path = os.path.expanduser(data.get('transcript_path', ''))
        model = data.get('model', {})
        model_id = model.get('display_name') or model.get('id') or 'unknown'
        session_id = data.get('session_id', '')

        # Resolve transcript path if not provided or doesn't exist
        if not transcript_path or not os.path.exists(transcript_path):
            cwd = os.getcwd()
            transcript_path = get_transcript_path(session_id, cwd) or transcript_path

        # Get git branch
        git_branch = get_git_branch()

        # Get directories
        cwd = os.getcwd()
        agent_dir = get_agent_dir(session_id)

        # Get token metrics (with GLM fix)
        token_data = estimate_tokens_from_transcript(transcript_path)
        context_length = token_data['context_length']

        # Build widgets
        widgets = []

        # 1. Model widget
        model_text = f'Model: {model_id}'
        if not token_data.get('has_real') and 'GLM' in model_id.upper():
            model_text += '(est)'
        widgets.append(model_text)

        # 2. Context Length widget (brightRed = 203, but in powerline theme it uses widget colors)
        ctx_k = context_length // 1000
        widgets.append(f'Ctx: {ctx_k}k')

        # 3. Context Percentage widget
        context_pct = (context_length / 200000) * 100
        widgets.append(f'Ctx: {context_pct:.1f}%')

        # 4. Git Branch widget
        if git_branch:
            widgets.append(f'⎇ {git_branch}')
        else:
            widgets.append('⎇ no git')

        # 5. Session ID widget (full ID)
        if session_id:
            widgets.append(session_id)

        # Calculate minimum width from model widget
        min_width = len(widgets[0]) + 2  # +2 for padding spaces

        # Pad all widgets to minimum width
        padded_widgets = []
        for widget in widgets:
            if len(widget) < min_width:
                # Center-align the content
                padding = min_width - len(widget)
                left_pad = padding // 2
                right_pad = padding - left_pad
                padded_widgets.append(' ' * left_pad + widget + ' ' * right_pad)
            else:
                padded_widgets.append(widget)

        # === Line 1: Original statusline ===
        output = []
        for i, widget in enumerate(padded_widgets):
            output.append(powerline_widget(widget, i, len(padded_widgets)))

        # === Line 2: Directory info ===
        output.append('\n')  # New line for second row

        # Build directory widgets for line 2
        dir_widgets = []

        # Current directory widget
        cwd_display = shorten_path(cwd)
        dir_widgets.append(f'DIR: {cwd_display}')

        # Agent directory widget
        if agent_dir:
            agent_display = shorten_path(agent_dir)
            dir_widgets.append(f'AGENT: {agent_display}')
        else:
            dir_widgets.append('AGENT: (none)')

        # Pad directory widgets
        dir_min_width = max(len(w) for w in dir_widgets) + 2
        padded_dir_widgets = []
        for widget in dir_widgets:
            if len(widget) < dir_min_width:
                padding = dir_min_width - len(widget)
                left_pad = padding // 2
                right_pad = padding - left_pad
                padded_dir_widgets.append(' ' * left_pad + widget + ' ' * right_pad)
            else:
                padded_dir_widgets.append(widget)

        # Render directory line with powerline (reuse same theme)
        for i, widget in enumerate(padded_dir_widgets):
            output.append(powerline_widget(widget, i, len(padded_dir_widgets)))

        print(''.join(output), end='')

    except Exception as e:
        # Fallback minimal output
        print('\x1b[38;5;231m\x1b[48;5;131m GLM-4.7 \x1b[0m', end='')

if __name__ == '__main__':
    main()
