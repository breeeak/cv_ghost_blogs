## Ghost Blogs 项目

一个基于 Ghost 6.x（Docker）的个人CV与自托管博客与作品集站点，包含：
- **Ghost 博客服务**（MySQL 8 持久化、主题热更新）
- **本地开发用 Mailpit**（捕获邮件）
- **生产环境反向代理接入**（Nginx，样例位于 `nginx/`）
- **自定义主题 `themes/cv-portfolio`**（含前端构建流程）
- **备份与恢复脚本**（数据库 + 内容）


### 组件与版本
- **Ghost**: `ghost:6-alpine`
- **MySQL**: `mysql:8`
- **Mailpit（本地）**: `axllent/mailpit:latest`


# 演示

https://mengshuo.xyz

上面是我的个人CV网站，如果你也想部署一个类似的网站，可以参考这个库

Ghost是一个很强大的博客库，有很多更好的主题，可以参考官网进行选择：https://ghost.org/

## 目录结构
```
.
├─ docker-compose.yml              # 本地开发 compose（含 mailpit）
├─ docker-compose.prod.yml         # 生产覆盖 compose（真实 SMTP、无端口暴露）
├─ themes/                         # 主题源码（挂载进容器）
│  └─ cv-portfolio/
│     ├─ assets/{css,js,built}     # 源码与构建产物
│     ├─ gulpfile.js               # 前端构建
│     └─ package.json
├─ data/
│  ├─ ghost/                       # Ghost 内容（持久化卷）
│  └─ mysql/                       # MySQL 数据（持久化卷）
├─ scripts/
│  ├─ backup.sh                    # 备份（DB + content）
│  ├─ restore.sh                   # 恢复（DB + content）
│  └─ upload_prod.sh               # 同步到生产服务器的辅助脚本
├─ nginx/                          # 反向代理示例（生产主机使用）
└─ backups/                        # 备份输出目录（脚本生成）
```


## 前置要求
- Docker 24+ 与 Docker Compose 插件
- Node.js（用于主题本地构建，推荐 LTS）


## 快速开始（本地）
1) 在项目根目录创建并填写 `.env`（或直接使用已有 `.env` 示例）：
```bash
GHOST_URL=http://localhost:2368
MYSQL_ROOT_PASSWORD=your_root
MYSQL_PASSWORD=your_user_pass
```

2) 启动服务：
```bash
docker compose up -d
```
- 博客访问：`http://localhost:2368`
- Mailpit（查看捕获邮件）：`http://localhost:8025`

3) 主题开发：
```bash
cd themes/cv-portfolio
npm ci
npx gulp build
```
- 修改 `assets/css/*` 或 `assets/js/*` 后重新执行 `npx gulp build`，产物输出到 `assets/built/`。
- `themes/` 已挂载进容器，刷新浏览器即可看到效果。
- 主题校验（可选）：
```bash
npx gscan .
```


## 生产部署
### 方式A：直接在服务器部署（推荐）
1) 在服务器目标目录（例如 `/home/www/cv-ghost-blog`）准备 `.env`：
```bash
GHOST_URL=https://your-domain
MYSQL_ROOT_PASSWORD=secure-root
MYSQL_PASSWORD=secure-user

# 腾讯企业邮箱（465/SSL）
SMTP_HOST=smtp.exmail.qq.com
SMTP_PORT=465
SMTP_SECURE="true"
SMTP_USER=no-reply@your-domain
SMTP_PASS=授权码或客户端专用密码
SMTP_FROM="Ghost <no-reply@your-domain>"
```

2) 启动生产服务（建议由反向代理接入 80/443）：
```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d ghost
```

3) 验证邮件：后台 → Settings → 邮件/Newsletter → 发送测试邮件；若失败，查看日志：
```bash
tail -n 200 ./data/ghost/logs/http___localhost_2368_production.error.log
```

4) 反向代理（示意）：使用外部 Nginx/Traefik，将 `https://your-domain` 反代到 compose 网络中的 `ghost:2368`。


### 方式B：使用同步脚本部署
本地执行（需要可用的 ssh 别名 `tecentserver`，目标目录 `/home/www/cv-ghost-blog`）：
```bash
# 上传仓库（基于 .gitignore 过滤），并在远程将 .env.prod 复制为 .env
scripts/upload_prod.sh

# 可选：带备份上传并在远程自动恢复
scripts/upload_prod.sh --with-backup --restore

# 上传后在远程启动/更新容器
ssh tecentserver "cd /home/www/cv-ghost-blog && docker compose -f docker-compose.yml -f docker-compose.prod.yml pull && docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d"
```


## 邮件配置要点（参考官方）
Ghost 支持通过环境变量映射 `config.production.json`，关键项（更多详见官方文档：[Configuration - Mail](https://docs.ghost.org/config#mail)）：
```bash
mail__transport=SMTP
mail__from="Ghost <no-reply@your-domain>"
mail__options__host=smtp.exmail.qq.com
mail__options__port=465
mail__options__secure=true           # 465 必须 true；若 587 则 false（STARTTLS）
mail__options__auth__user=no-reply@your-domain
mail__options__auth__pass=授权码
```
常见错误与排查：
- 将 `SMTP_SECURE` 写成 `SMTP_SCURE`，会导致回落为默认 false，从而 465 连接超时（ETIMEDOUT）。
- `SMTP_FROM` 建议加引号，避免空格导致解析问题。
- 腾讯企业邮箱需使用“客户端授权码”，而非网页登录密码。
- 发件人与账号需一致或为其授权别名。
- 连通性测试（若容器没有 openssl，可在宿主机执行）：
```bash
openssl s_client -connect smtp.exmail.qq.com:465 -servername smtp.exmail.qq.com
openssl s_client -connect smtp.exmail.qq.com:587 -starttls smtp -servername smtp.exmail.qq.com
```


## 主题上线与回滚
- 方式A：后台上传主题 ZIP：
```bash
cd themes/cv-portfolio
npx gulp build
zip -r cv-portfolio.zip . -x "node_modules/*" ".git/*" ".DS_Store" "*.zip"
# Ghost 后台 → Design → Themes → Upload theme → Activate
```
- 方式B：Git 拉取 + 重启容器（推荐）：
```bash
# 本地
cd themes/cv-portfolio
npx gulp build
git add -A && git commit -m "feat(theme): update cv-portfolio" && git push

# 服务器
cd /home/www/cv-ghost-blog
git pull
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d ghost
```
- 回滚：后台切回上一个主题，或 `git revert` 后 `git pull` 并重启。


## 备份与恢复
- 备份（输出至 `backups/YYYYmmdd_HHMMSS/`）：
```bash
./scripts/backup.sh
```
- 恢复：
```bash
./scripts/restore.sh backups/20250830_182852
```
- 备份内容包含：
  - `db.sql`（mysqldump）
  - `content.tar.gz`（Ghost 内容：images、themes、routes.yaml 等）
  - `manifest.env`（元信息）


## 常见问题 FAQ
- 邮件发送失败（ETIMEDOUT）
  - 检查 `SMTP_SECURE` 与端口协商（465→true，587→false）
  - 使用授权码、发件人与账号一致
  - 服务器上执行 openssl 连通性测试
- 页面无样式或脚本
  - 忘记 `npx gulp build` 或未提交 `assets/built/*`
  - 模板静态资源路径应指向 `assets/built/style.css`、`assets/built/main.js`
- 数据库连接失败
  - 确保 `MYSQL_ROOT_PASSWORD`、`MYSQL_PASSWORD` 与 compose 一致
  - 保证持久化卷 `./data/mysql` 未被误删或权限异常


## 维护建议
- 主题开发走分支 → 本地构建 → GScan 校验 → 合并 → 服务器拉取 → 重启
- 将 `assets/built/*` 连同主题代码一并提交，避免服务器 Node 环境偏差
- 定期执行备份并将 `backups/` 异地保存


## 许可
- 主题 `cv-portfolio`：MIT
- 其它部分按仓库 `LICENSE` 说明
