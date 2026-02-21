# neovim installation
sudo add-apt-repository ppa:neovim-ppa/unstable
sudo apt-get update
sudo apt-get install neovim

sudo update-alternatives --install /usr/bin/vim vim /usr/bin/nvim 60
sudo update-alternatives --install /usr/bin/view view /usr/bin/nvim 60
sudo update-alternatives --install /usr/bin/vimdiff vimdiff /usr/bin/nvim 60

sudo update-alternatives --config vim
sudo update-alternatives --config vi



# warp.dev
wget https://app.warp.dev/download?package=deb -O warp.deb
sudo apt install ./warp.deb



# sandbox
sudo apt-get install bubblewrap socat



# playwright, and playwright for claude
# 1. 初始化并安装 Playwright (用 npm 替代 pnpm)
npm install -D @playwright/test

# 2. 安装浏览器内核
npx playwright install

# 3. 【关键一步】安装 Ubuntu 系统级依赖
# 你的服务器是无头环境，必须跑这一步安装 libgtk/libnss 等库，否则浏览器启动会报错
npx playwright install-deps

sudo docker run -d --rm --init --pull=always \
  --name playwright-mcp \
  -p 8931:8931 \
  --entrypoint node \
  mcr.microsoft.com/playwright/mcp \
  cli.js --headless --browser chromium --no-sandbox \
  --host 0.0.0.0 --allowed-hosts '*' --port 8931

# 只要能连上（哪怕返回 404/405/400），都说明“连接”没问题了
curl -v http://127.0.0.1:8931/mcp

claude mcp remove playwright 2>/dev/null || true
claude mcp add --transport http playwright http://127.0.0.1:8931/mcp --scope user

npm install stagehand

# fix Chinese font issues.
sudo apt-get install fonts-noto-cjk

## 可选：先清掉你本地 scope 里已有的同名（避免你以前加过）
#claude mcp remove playwright --scope local 2>/dev/null || true

## 关键：同名 + local scope，指向你的 Docker MCP
#claude mcp add --transport http playwright --scope local http://127.0.0.1:8931/mcp



# status bar
npx ccstatusline@latest

# ============================================================================
# VS Code Server (code-server) - Remote access via browser
# ============================================================================
# Install code-server standalone (no sudo required)
CODE_SERVER_VERSION="4.108.2"
curl -fsSL "https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server-${CODE_SERVER_VERSION}-linux-amd64.tar.gz" -o /tmp/code-server.tar.gz
tar -xzf /tmp/code-server.tar.gz -C ~/.local --strip-components=1
rm /tmp/code-server.tar.gz

# Configure code-server
mkdir -p ~/.config/code-server
cat > ~/.config/code-server/config.yaml << 'YAML_EOF'
bind-addr: 0.0.0.0:8080
auth: password
password: Summer11
cert: false
YAML_EOF

# Start code-server in background
mkdir -p ~/.logs
pkill -f "code-server" 2>/dev/null || true
nohup ~/.local/bin/code-server > ~/.logs/code-server.log 2>&1 &

sleep 3
echo "============================================"
echo "code-server is RUNNING"
echo "============================================"
echo "URL:  http://$(hostname -I | awk '{print $1}'):8080"
echo "Password: Summer11"
echo "============================================"

# Install VS Code extensions (Copilot and Claude Code)
CODE_SERVER_EXT_DIR="$HOME/.local/share/code-server/extensions"
if [ ! -d "$CODE_SERVER_EXT_DIR/anthropic.claude-code" ]; then
    echo "Installing Claude Code extension..."
    curl -sL "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/anthropic/vsextensions/claude-code/latest/vspackage" | \
      gunzip > ~/claude-code.vsix.tmp && \
      ~/.local/bin/code-server --install-extension ~/claude-code.vsix.tmp && \
      rm ~/claude-code.vsix.tmp
fi

if [ ! -d "$CODE_SERVER_EXT_DIR/github.copilot" ]; then
    echo "Installing GitHub Copilot extension..."
    curl -sL "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/github/vsextensions/copilot/latest/vspackage" | \
      gunzip > ~/copilot.vsix.tmp && \
      ~/.local/bin/code-server --install-extension ~/copilot.vsix.tmp && \
      rm ~/copilot.vsix.tmp
fi

echo "✓ VS Code extensions installed"



npm install -g pyright
npm install -g typescript-language-server typescript
sudo snap install go --classic
go install golang.org/x/tools/gopls@latest
if ! grep -q 'GOPATH' ~/.bashrc; then
  echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc
  echo "已成功添加到 .bashrc"
else
  echo "配置已存在，跳过添加"
fi
sudo snap install rustup --classic
rustup default stable
rustup component add rust-analyzer

# 安装 JDK 21
#
sudo apt install openjdk-21-jdk

# 需要 Node.js 环境
npm install -g @mixedbread/mgrep
mgrep login
# 这会给出一个 URL，在浏览器登录后授权
mgrep install-claude-code

