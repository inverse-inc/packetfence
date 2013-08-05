cd /usr/local/pf
git init-db
chmod og-rwx .git
cat <<'EOF' > .gitignore
*.lock
*~
logs/
var/
EOF
git add .
git commit -a -m"initial import"

