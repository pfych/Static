#!/usr/bin/env bash
# shellcheck disable=SC2231

shopt -s failglob

###############
# USER CONFIG #
###############

export AWS_REGION='ap-southeast-2'
DOMAIN_NAME='pfy.ch'
DOMAIN_BASE='www'

##########
# SCRIPT #
##########

PARENT_PATH="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )/"
cd "$PARENT_PATH"

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
mkdir -p out/
mkdir -p out/blog/
mkdir -p out/blog/images
mkdir -p out/fonts/
cp src/index.html out/
cp src/404.html out/
cp src/fonts/* out/fonts
find src/ -name '*.scss' -exec sass {} ./out/bundle.css \;
find src/ -name '*.ts' -exec tsc {} --outfile ./out/bundle.js \;

if [ ! -f "./static-rs" ]; then
  curl -s https://api.github.com/repos/pfych/static-rs/releases/latest \
    | grep "browser_download_url" \
    | cut -d '"' -f 4 \
    | wget -i - -O static-rs
fi

if [ ! -f "./config.json" ]; then
  echo "Missing config file"
  exit 1
fi

chmod +x ./static-rs
./static-rs

# Deploy to AWS
read -rp "Deploy (y/N)? " choice
case "$choice" in
  y|Y )
    echo "Deploying..."
    aws s3 sync "$PARENT_PATH/out/" s3://$BUCKET_NAME/
    aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy "$POLICY"
    aws s3 website s3://$BUCKET_NAME/ --index-document index.html --error-document 404.html
    CLOUDFRONT_DISTRIBUTION_ID=$(aws cloudfront list-distributions | jq --arg domain "$BUCKET_NAME" '.DistributionList.Items | map(select(.Aliases.Items != null)) | map(select(.Aliases.Items[]  | contains ($domain))) | .[] .Id' | sed 's/"//g')
    if [ "${CLOUDFRONT_DISTRIBUTION_ID:-"_"}" == "_" ]; then
      echo "No cloudfront cache"
    else
      aws cloudfront create-invalidation --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" --paths "/*" >> /dev/null
      echo "Invalidated cache"
    fi;;
  *) echo "Skipping deploy...";;
esac

echo "Done!"
