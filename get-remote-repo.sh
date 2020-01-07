GITUSER="root"
GITURL=$(echo -n "https://" ; kubectl -n gitlab get ingress gitlab-unicorn -ojsonpath='{.spec.rules[0].host}' ; echo)
GITROOTPWD=$(kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 --decode ; echo)

# 1. curl for the login page to get a session cookie and the sources with the auth tokens
body_header=$(curl -k -c gitlab-cookies.txt -i "${GITURL}/users/sign_in" -sS)

# grep the auth token for the user login for
#   not sure whether another token on the page will work, too - there are 3 of them
csrf_token=$(echo $body_header | perl -ne 'print "$1\n" if /new_user.*?authenticity_token"[[:blank:]]value="(.+?)"/' | sed -n 1p)

# 2. send login credentials with curl, using cookies and token from previous request
curl -sS -k -b gitlab-cookies.txt -c gitlab-cookies.txt "${GITURL}/users/sign_in" \
        --data "user[login]=${GITUSER}&user[password]=${GITROOTPWD}" \
        --data-urlencode "authenticity_token=${csrf_token}"  -o /dev/null

# 3. send curl GET request to projects/new page
body_header=$(curl -k -H 'user-agent: curl' -b cookies.txt -i "${GITURL}/projects/new" -sS)
csrf_token=$(echo $body_header | perl -ne 'print "$1\n" if /authenticity_token"[[:blank:]]value="(.+?)"/' | sed -n 1p)

# 4. send curl POST to copy github project
body_header=$(curl -sS -k -L -b gitlab-cookies.txt "${GITURL}/projects" \
	--data-urlencode "authenticity_token=${csrf_token}"  \
	--data "project[import_url]=https://github.com/MxNxPx/gitlab-cicd-demo.git&project[import_url_user]=&project[import_url_password]=&project[ci_cd_only]=false&project[name]=gitlab-cicd-demo&project[namespace_id]=1&project[path]=gitlab-cicd-demo&project[description]=&project[visibility_level]=20")

echo $body_header
