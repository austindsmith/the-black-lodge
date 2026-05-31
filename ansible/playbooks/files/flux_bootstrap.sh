echo "y" | flux bootstrap git \
  --url=ssh://git@github.com/austindsmith/the-black-lodge \
  --branch=main \
  --path=kubernetes/clusters/staging \
  --private-key-file=/home/austin/.ssh/keys/austin@theblacklodge.org
