# lib/new.sh - project templates for `tkit new`

TEMPLATES=(python-cli flask-api express-api static-site telegram-bot)

template_desc() {
  case "$1" in
    python-cli)   echo "Python command-line app (argparse)" ;;
    flask-api)    echo "REST API with Flask" ;;
    express-api)  echo "REST API with Express (Node.js)" ;;
    static-site)  echo "HTML / CSS / JS website" ;;
    telegram-bot) echo "Telegram bot (long polling)" ;;
  esac
}

template_needs() {
  case "$1" in
    express-api) echo "nodejs" ;;
    *)           echo "python" ;;
  esac
}

template_run() {
  case "$1" in
    python-cli)   echo "python main.py --help" ;;
    flask-api)    echo "pip install -r requirements.txt && python app.py" ;;
    express-api)  echo "npm install && npm start" ;;
    static-site)  echo "python -m http.server 8000" ;;
    telegram-bot) echo "pip install -r requirements.txt && BOT_TOKEN=xxx python bot.py" ;;
  esac
}

# ---- template bodies ----------------------------------------------------
tpl_python_cli() {
cat > main.py << 'EOF'
#!/usr/bin/env python3
import argparse


def main():
    parser = argparse.ArgumentParser(description="__NAME__")
    parser.add_argument("name", nargs="?", default="world", help="who to greet")
    parser.add_argument("-s", "--shout", action="store_true", help="UPPERCASE output")
    args = parser.parse_args()

    msg = f"Hello, {args.name}!"
    print(msg.upper() if args.shout else msg)


if __name__ == "__main__":
    main()
EOF
printf '__pycache__/\n.venv/\n.env\n*.pyc\n' > .gitignore
}

tpl_flask_api() {
cat > app.py << 'EOF'
from flask import Flask, jsonify, request

app = Flask(__name__)
items = []


@app.get("/health")
def health():
    return jsonify(status="ok")


@app.get("/items")
def list_items():
    return jsonify(items)


@app.post("/items")
def add_item():
    data = request.get_json(silent=True) or {}
    name = data.get("name")
    if not name:
        return jsonify(error="name is required"), 400
    item = {"id": len(items) + 1, "name": name}
    items.append(item)
    return jsonify(item), 201


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
EOF
printf 'flask\n' > requirements.txt
printf '__pycache__/\n.venv/\n.env\n*.pyc\n' > .gitignore
cat > README.md << 'EOF'
# __NAME__

Flask REST API.

    pip install -r requirements.txt
    python app.py

Try it:

    curl localhost:5000/health
    curl -X POST localhost:5000/items -H 'Content-Type: application/json' -d '{"name":"demo"}'
    curl localhost:5000/items
EOF
}

tpl_express_api() {
cat > package.json << 'EOF'
{
  "name": "__NAME__",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js"
  },
  "dependencies": {
    "express": "^4.19.2"
  }
}
EOF
cat > index.js << 'EOF'
const express = require("express");

const app = express();
app.use(express.json());

const items = [];

app.get("/health", (req, res) => res.json({ status: "ok" }));
app.get("/items", (req, res) => res.json(items));
app.post("/items", (req, res) => {
  const { name } = req.body || {};
  if (!name) return res.status(400).json({ error: "name is required" });
  const item = { id: items.length + 1, name };
  items.push(item);
  res.status(201).json(item);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, "0.0.0.0", () => console.log(`Listening on :${PORT}`));
EOF
printf 'node_modules/\n.env\n' > .gitignore
cat > README.md << 'EOF'
# __NAME__

Express REST API.

    npm install
    npm start        # or: npm run dev

Try it:

    curl localhost:3000/health
EOF
}

tpl_static_site() {
cat > index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>__NAME__</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <main>
    <h1>__NAME__</h1>
    <p>Built on my phone with Termux.</p>
    <button id="btn">Click me</button>
    <p id="out"></p>
  </main>
  <script src="script.js"></script>
</body>
</html>
EOF
cat > style.css << 'EOF'
:root { color-scheme: light dark; }
body { font-family: system-ui, sans-serif; margin: 0; display: grid; place-items: center; min-height: 100vh; }
main { text-align: center; padding: 1rem; }
button { padding: .6rem 1.2rem; font-size: 1rem; border-radius: .5rem; border: 0; background: #2f81f7; color: #fff; }
EOF
cat > script.js << 'EOF'
let count = 0;
document.getElementById("btn").addEventListener("click", () => {
  count += 1;
  document.getElementById("out").textContent = `Clicked ${count} time(s)`;
});
EOF
printf '# __NAME__\n\n    python -m http.server 8000\n\nThen open http://localhost:8000\n' > README.md
}

tpl_telegram_bot() {
cat > bot.py << 'EOF'
import os
import time

import requests

TOKEN = os.environ.get("BOT_TOKEN")
if not TOKEN:
    raise SystemExit("Set BOT_TOKEN first, e.g.  export BOT_TOKEN=123456:ABC")

API = f"https://api.telegram.org/bot{TOKEN}"


def send(chat_id, text):
    requests.post(f"{API}/sendMessage", json={"chat_id": chat_id, "text": text}, timeout=30)


def handle(msg):
    text = (msg.get("text") or "").strip()
    chat_id = msg["chat"]["id"]
    if text == "/start":
        send(chat_id, "Hello! I'm running on Termux.")
    elif text == "/ping":
        send(chat_id, "pong")
    elif text:
        send(chat_id, f"You said: {text}")


def main():
    offset = None
    print("Bot started. Press Ctrl+C to stop.")
    while True:
        try:
            r = requests.get(
                f"{API}/getUpdates",
                params={"timeout": 30, "offset": offset},
                timeout=40,
            ).json()
            for update in r.get("result", []):
                offset = update["update_id"] + 1
                if "message" in update:
                    handle(update["message"])
        except requests.RequestException as e:
            print("network error:", e)
            time.sleep(5)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nBye!")
EOF
printf 'requests\n' > requirements.txt
printf '__pycache__/\n.venv/\n.env\n*.pyc\n' > .gitignore
cat > README.md << 'EOF'
# __NAME__

Telegram bot. Get a token from @BotFather, then:

    pip install -r requirements.txt
    export BOT_TOKEN=123456:ABC
    python bot.py
EOF
}

# ---- scaffold ---------------------------------------------------------------
scaffold() {
  local tpl="$1" name="$2" dir fn need
  [[ " ${TEMPLATES[*]} " == *" $tpl "* ]] || { ui_err "Unknown template: $tpl"; return 1; }
  [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || { ui_err "Invalid name (use letters, numbers, . _ -)"; return 1; }
  dir="$PWD/$name"
  [ -e "$dir" ] && { ui_err "Already exists: $dir"; return 1; }

  need=$(template_needs "$tpl")
  command -v "$need" >/dev/null 2>&1 || command -v "${need/nodejs/node}" >/dev/null 2>&1 \
    || ui_warn "'$need' is not installed  ->  tkit install $need"

  if (( DRY_RUN )); then
    ui_info "Would create ./$name from template '$tpl'"; return 0
  fi

  mkdir -p "$dir"
  fn="tpl_${tpl//-/_}"
  ( cd "$dir" && "$fn" && find . -type f -exec sed -i "s/__NAME__/$name/g" {} + ) || return 1
  [ "$tpl" = python-cli ] && chmod +x "$dir/main.py"
  command -v git >/dev/null 2>&1 && git -C "$dir" init -q 2>/dev/null

  ui_rule "Created $name"
  ( cd "$dir" && find . -type f -not -path './.git/*' | sort | sed 's|^\./|    |' )
  echo
  ui_ok "Next steps"
  printf '    cd %s\n    %s\n' "$name" "$(template_run "$tpl")"
}

cmd_new() {
  local tpl="${1:-}" name="${2:-}" t
  if [ -z "$tpl" ]; then
    ui_rule "Templates"
    for t in "${TEMPLATES[@]}"; do
      printf '  %s%-13s%s %s%s%s\n' "$ACC" "$t" "$NC" "$GRY" "$(template_desc "$t")" "$NC"
    done
    echo; ui_info "Usage: tkit new <template> <name>"
    return
  fi
  [ -n "$name" ] || die "Usage: tkit new $tpl <name>"
  scaffold "$tpl" "$name"
}
