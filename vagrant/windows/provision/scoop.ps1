Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
# If run as admin error occurs, use the below
# iex "& {$(irm get.scoop.sh)} -RunAsAdmin"
