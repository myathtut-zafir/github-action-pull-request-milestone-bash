#!/bin/bash

if [[ "$GITHUB_EVENT_NAME" != "pull_request" ]]; then
  echo "This action only runs on pull_request.closed"
  echo "Found: $GITHUB_EVENT_NAME"
  exit 1
fi

ACTION=$(jq -r ".action" $GITHUB_EVENT_PATH)
if [[ "$ACTION" != "closed" ]]; then
  echo "This action only runs on pull_request.closed"
  echo "Found: $GITHUB_EVENT_NAME.$ACTION"
  exit 1
fi

IS_MERGED=$(jq -r ".pull_request.merged" $GITHUB_EVENT_PATH)
if [[ "$IS_MERGED" != "true" ]]; then
  echo "Pull request closed without merge"
  exit 0
fi

PULLS=""
URL="https://api.github.com/repos/$GITHUB_REPOSITORY/pulls?state=closed&per_page=100"
while [ "$URL" ]; do
      RESP=$(curl -i -Ss -H "Authorization: token $GITHUB_TOKEN" "$URL")
      HEADERS=$(echo "$RESP" | sed '/^\r$/q')
      URL=$(echo "$HEADERS" | sed -n -E 's/Link:.*<(.*?)>; rel="next".*/\1/p')
      PULLS="$PULLS $(echo "$RESP" | sed '1,/^\r$/d')"
done

PR_AUTHOR=$(jq -r ".pull_request.user.login" $GITHUB_EVENT_PATH)

MERGED_COUNT=$(echo $PULLS | jq -c ".[] | select(.merged_at != null and .user.login == \"$PR_AUTHOR\")" | wc -l | tr -d '[:space:]')

COMMENT_VAR="INPUT_MERGED_${MERGED_COUNT}"
COMMENT=${!COMMENT_VAR}

if [[ -z "$COMMENT" ]]; then
  echo "No action required"
  exit 0
fi

ISSUE_NUMBER=$(jq -r ".pull_request.number" $GITHUB_EVENT_PATH)

POSTBODY=$(echo $COMMENT | jq -c -R '. | {"body": .}')

COMMENT_ADDED=$(curl -i -Ss -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUMBER/comments" -d "$POSTBODY")

# Check if the comment was successfully added
echo $COMMENT_ADDED | head -n1 | grep "201 Created" > /dev/null
if [[ $? -eq 1 ]]; then
  echo "Error creating comment:"
  echo "$COMMENT_ADDED" | sed '1,/^\r$/d'
  exit 1
fi

echo "Added comment:"
echo $COMMENT

# Add labels
LABELS='{"labels":["merge-milestone","merge-milestone:'$MERGED_COUNT'"]}'
LABELS_ADDED=$(curl -i -Ss -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUMBER/labels" -d $LABELS)

# Check if the labels were successfully added
echo $LABELS_ADDED | head -n1 | grep "200 OK" > /dev/null
if [[ $? -eq 1 ]]; then
  echo "Error Adding Labels:"
  echo "$LABELS_ADDED" | sed '1,/^\r$/d'
  exit 1
fi