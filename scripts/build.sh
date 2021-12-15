#!/usr/bin/env bash
# shellcheck disable=SC2231

shopt -s failglob
set -eu -o pipefail

# Get Path to root directory assuming this script sits 1 folder above root
PARENT_PATH="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )/.."
cd "$PARENT_PATH"

export AWS_REGION='ap-southeast-2'
BLOG_LOCATION=/home/pfych/Documents/Scratchpad-write
DOMAIN_NAME='pfy.ch'
DOMAIN_BASE='www'
BUCKET_NAME="${DOMAIN_BASE}.${DOMAIN_NAME}"
POLICY="{
  \"Version\": \"2012-10-17\",
  \"Statement\": [
    {
      \"Sid\": \"PublicReadGetObject\",
      \"Effect\": \"Allow\",
      \"Principal\": \"*\",
      \"Action\": \"s3:GetObject\",
      \"Resource\": \"arn:aws:s3:::$BUCKET_NAME/*\"
    }
  ]
}"

# Move files
cp src/index.html out/
find src/ -name '*.scss' -exec sass {} ./out/bundle.css \;

# Compile Blogs
for file in $BLOG_LOCATION/*; do
  NAME="$(basename "$file")"
  pandoc "$file" -o ./out/blog/"${NAME%-write.md}".html --template ./src/blog/index.html
done

# Create a table of contents
TOC=()
for file in $BLOG_LOCATION/*; do
  NAME="$(basename "$file")"
  TOC+=("<a href='/blog/${NAME%-write.md}.html'>${NAME%-write.md}</a>")
done

TOCString=$(printf '%s' "${TOC[@]}")
sed -i -e "s|TOC|$TOCString|g" ./out/index.html

# Deploy to AWS
aws s3 sync "$PARENT_PATH/out/" s3://$BUCKET_NAME/
aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy "$POLICY"
aws s3 website s3://$BUCKET_NAME/ --index-document index.html --error-document 404.html
CLOUDFRONT_DISTRIBUTION_ID=$(aws cloudfront list-distributions | jq --arg domain "$BUCKET_NAME" '.DistributionList.Items | map(select(.Aliases.Items != null)) | map(select(.Aliases.Items[]  | contains ($domain))) | .[] .Id' | sed 's/"//g')
if [ "${CLOUDFRONT_DISTRIBUTION_ID:-"_"}" == "_" ]; then
  echo "No cloudfront cache"
else
  aws cloudfront create-invalidation --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" --paths "/*" >> /dev/null
  echo "Invalidated cache"
fi
