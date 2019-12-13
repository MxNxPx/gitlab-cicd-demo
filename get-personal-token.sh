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

# 3. send curl GET request to personal access token page to get auth token
body_header=$(curl -k -H 'user-agent: curl' -b cookies.txt -i "${GITLABURL}/profile/personal_access_tokens" -sS)
csrf_token=$(echo $body_header | perl -ne 'print "$1\n" if /authenticity_token"[[:blank:]]value="(.+?)"/' | sed -n 1p)

# 4. curl POST request to send the "generate personal access token form"
#      the response will be a redirect, so we have to follow using `-L`
body_header=$(curl -sS -k -L -b gitlab-cookies.txt "${GITLABURL}/profile/personal_access_tokens" \
	--data-urlencode "authenticity_token=${csrf_token}" \
	--data 'personal_access_token[name]=api-token&personal_access_token[expires_at]=&personal_access_token[scopes][]=api')

# 5. Scrape the personal access token from the response HTML
personal_access_token=$(echo $body_header | perl -ne 'print "$1\n" if /created-personal-access-token"[[:blank:]]value="(.+?)"/' | sed -n 1p)
echo $personal_access_token
