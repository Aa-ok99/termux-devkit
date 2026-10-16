tkit — Termux DevKit

```
╔══════════════════════════════════════════════════════════════╗
║  tkit — Turn Termux into a complete development workstation  ║
║         เปลี่ยน Termux ให้เป็นเวิร์กสเตชันสำหรับพัฒนา        ║
╚══════════════════════════════════════════════════════════════╝
```

one command. full workstation.

---

⚡ Install

```bash
$ pkg install git -y
$ git clone https://github.com/Aa-ok99/termux-devkit.git
$ cd termux-devkit && bash install.sh
$ tkit
```

---

🎛 Commands

```
USAGE:
  tkit <command> [args...] [options]

COMMANDS:
  tkit                                Interactive menu (arrow keys, space, enter)
  tkit install <mod...|all>           Install modules        (aliases: add, i)
  tkit remove  <mod...>               Remove modules         (alias: rm)
  tkit list    [--installed]          List modules & status  (alias: ls)
  tkit info    <module>               Show module details
  tkit search  <word>                 Search modules
  tkit profile [name]                 Install a bundle
  tkit new     <template> <name>      Scaffold a project
  tkit doctor                         Diagnose environment
  tkit update                         Update packages
  tkit self-update                    Update tkit itself
  tkit log                            Show install log

OPTIONS:
  -y, --yes          Assume yes to prompts
  -n, --dry-run      Preview actions without executing
      --no-color     Disable colored output
  -h, --help         Show help
```

---

📦 Modules

```
┌─────────────┬──────────────────────────────────────────────┐
│ CATEGORY    │ MODULES                                      │
├─────────────┼──────────────────────────────────────────────┤
│ Essentials  │ storage  base  shell  git                    │
│ Languages   │ python   nodejs                              │
│ Platforms   │ web      android                             │
│ Tools       │ devtools automation                          │
└─────────────┴──────────────────────────────────────────────┘
```

---

🧩 Profiles

```
  minimal   ─  base essentials only
  web       ─  web development stack
  backend   ─  server-side development stack
  android   ─  Android tooling
  full      ─  everything
```

```bash
$ tkit profile web
```

---

🏗 Project Templates

```
  python-cli      flask-api      express-api
  static-site     telegram-bot
```

```bash
$ tkit new flask-api my-api
```

---

🔧 Add Your Own Module

Create ~/.config/tkit/modules/<name>.sh
(see modules/_template.sh.example):

```bash
MOD_DESC="My tools"
MOD_CAT="Tools"
MOD_DEPS="base"
MOD_PKGS="htop btop"
```

Then run:

```bash
$ tkit install <name>
```

---

🩺 Health Check

```bash
$ tkit doctor
```

---

📄 License

```
MIT
```

---

```
$ echo "happy hacking ▸"
```