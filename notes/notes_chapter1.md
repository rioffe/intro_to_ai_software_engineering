# Chapter 1 notes

## 1.2

define the language model first

include a mermaid diagram of concepts in 1.2 

## 1.4.2

On macOS it is better to get qwen3.8:27b-mlx: it is 18 GB, but is optimized for mac hardware.

## 1.5.3

pi config  DOES NOT have set option; set the model by editing  defaultModel and defaultProvider and defaultThinkingLevel in 
~/.pi/agent/settings.json - here is where vi comes in handy. Here is my settings file (you can ignore packages part for now).

{
  "defaultModel": "qwen3.8:27b-mlx",
  "defaultProvider": "ollama",
  "defaultThinkingLevel": "medium",
  "lastChangelogVersion": "0.84.4",
  "packages": [
    "npm:pi-mcp-adapter",
    "npm:@ollama/pi-web-search",
    "npm:pi-execution-time",
    "npm:pi-metrics",
    "git:github.com/obra/superpowers",
    "npm:@juicesharp/rpiv-todo",
    "npm:context-mode",
    "npm:@juicesharp/rpiv-ask-user-question",
    "npm:pi-lens"
  ],
  "quietStartup": true,
  "theme": "dark",
  "compaction": {
    "enabled": true
  },
  "httpIdleTimeoutMs": 0
}

## 1.5.4

there is no pi skills command; Skills are viewable via interactive pi config
To add a global skill user needs to copy it to a global ~/.pi/agent/skills.
Skills can be local and live in .pi/agent/skills of a project

## 1.5.5

There is no pi init command; Only these are available:

Commands:
  pi install <source> [-l]     Install extension source and add to settings
  pi remove <source> [-l]      Remove extension source from settings
  pi uninstall <source> [-l]   Alias for remove
  pi update [source|self|pi]   Update pi, extensions, or model catalogs
  pi list                      List installed extensions from settings
  pi config [-l]               Open TUI to enable/disable package resources (Tab switches scope)
  pi auth <command>            Print credentials or check provider readiness
  pi <command> --help          Show help for install/remove/uninstall/update/list/config/auth


Pi can just be started by running: pi 

All mortgage-calculator refs should be mortgage-calculator-book refs.

## 1.6

example will run, but the user will end up in interactive mode; with -p it is non-interactive.
If interactive, we need to instruct the user how to exit (Ctrl+D) the session


## 1.7.2

again, there is not pi config command (see above)

With OpenRouter, tell the user to put some money in the account there :) 

Also split the pi lines everywehre so they are readable in the book:

pi "Add a one-line docstring to the top of \
    src/mortgage-calculator-book/__init__.py describing \
    what this package is for."


