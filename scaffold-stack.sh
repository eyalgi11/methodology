#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: scaffold-stack.sh [--git] <stack> <target-directory>

Supported stacks:
  next
  vite
  fastapi
  express
  node-cli
EOF
}

init_git=0
stack=""
target_dir=""

while (($# > 0)); do
  case "$1" in
    --git) init_git=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      if [[ -z "$stack" ]]; then
        stack="$1"
      elif [[ -z "$target_dir" ]]; then
        target_dir="$1"
      else
        echo "Too many arguments." >&2
        usage >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$stack" || -z "$target_dir" ]]; then
  usage >&2
  exit 1
fi

mkdir -p "$target_dir"

case "$stack" in
  next)
    mkdir -p "$target_dir/app"
    cat > "$target_dir/package.json" <<'EOF'
{
  "name": "next-app",
  "private": true,
  "version": "1.0.0",
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "^15.0.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "@types/react": "^19.0.0",
    "@types/node": "^22.0.0"
  }
}
EOF
    cat > "$target_dir/tsconfig.json" <<'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["dom", "dom.iterable", "es2020"],
    "jsx": "preserve",
    "module": "esnext",
    "moduleResolution": "bundler",
    "strict": true
  }
}
EOF
    cat > "$target_dir/app/layout.tsx" <<'EOF'
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
EOF
    cat > "$target_dir/app/page.tsx" <<'EOF'
export default function HomePage() {
  return (
    <main>
      <h1>Next app scaffold</h1>
    </main>
  );
}
EOF
    ;;
  vite)
    mkdir -p "$target_dir/src"
    cat > "$target_dir/package.json" <<'EOF'
{
  "name": "vite-app",
  "private": true,
  "version": "1.0.0",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "react": "^19.0.0",
    "react-dom": "^19.0.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "vite": "^6.0.0",
    "@vitejs/plugin-react": "^4.0.0"
  }
}
EOF
    cat > "$target_dir/index.html" <<'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Vite App</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF
    cat > "$target_dir/src/main.tsx" <<'EOF'
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF
    cat > "$target_dir/src/App.tsx" <<'EOF'
export default function App() {
  return <h1>Vite app scaffold</h1>;
}
EOF
    cat > "$target_dir/tsconfig.json" <<'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "jsx": "react-jsx",
    "moduleResolution": "bundler",
    "strict": true
  }
}
EOF
    ;;
  fastapi)
    mkdir -p "$target_dir/app"
    cat > "$target_dir/requirements.txt" <<'EOF'
fastapi>=0.115.0
uvicorn[standard]>=0.32.0
pytest>=8.0.0
EOF
    cat > "$target_dir/app/main.py" <<'EOF'
from fastapi import FastAPI

app = FastAPI()


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
EOF
    ;;
  express)
    mkdir -p "$target_dir/src"
    cat > "$target_dir/package.json" <<'EOF'
{
  "name": "express-app",
  "private": true,
  "version": "1.0.0",
  "scripts": {
    "dev": "node src/server.js",
    "test": "node -e \"console.log('add tests')\"",
    "lint": "node -e \"console.log('add lint')\""
  },
  "dependencies": {
    "express": "^4.21.0"
  }
}
EOF
    cat > "$target_dir/src/server.js" <<'EOF'
const express = require("express");

const app = express();
app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`Listening on ${port}`);
});
EOF
    ;;
  node-cli)
    mkdir -p "$target_dir/src"
    cat > "$target_dir/package.json" <<'EOF'
{
  "name": "node-cli",
  "private": true,
  "version": "1.0.0",
  "bin": {
    "node-cli": "./src/index.js"
  },
  "scripts": {
    "start": "node src/index.js",
    "test": "node -e \"console.log('add tests')\""
  }
}
EOF
    cat > "$target_dir/src/index.js" <<'EOF'
#!/usr/bin/env node
console.log("node-cli scaffold");
EOF
    chmod +x "$target_dir/src/index.js"
    ;;
  *)
    echo "Unsupported stack: $stack" >&2
    usage >&2
    exit 1
    ;;
esac

if (( init_git == 1 )); then
  "$SCRIPT_DIR/init-project.sh" --git "$target_dir" >/dev/null
else
  "$SCRIPT_DIR/init-project.sh" "$target_dir" >/dev/null
fi
"$SCRIPT_DIR/repo-intake.sh" "$target_dir" >/dev/null
bash "$SCRIPT_DIR/fix-project-perms.sh" "$target_dir" >/dev/null || true

echo "Scaffolded $stack project at $target_dir"
echo "Methodology initialized and repo intake completed."
echo "Dependencies were not installed automatically."
