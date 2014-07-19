git add .
git commit -m wip
git push origin master
ssh docker-001.linode "cd docker-manifest && git pull origin master"
