#!/usr/bin/env bash
# shellcheck disable=SC2231

shopt -s failglob
set -eu -o pipefail

PARENT_PATH="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )/"
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
echo "Running pandoc..."
for file in $BLOG_LOCATION/*.md; do
  NAME="$(basename "$file")"
  pandoc "$file" -o ./out/blog/"${NAME%-write.md}".html --template ./src/blog/index.html
done

# Move images
echo "Resizing images..."
for file in $BLOG_LOCATION/images/*; do
  NAME="$(basename "$file")"
  if [ ! -f "./out/blog/images/${NAME%.*}.jpg;" ]; then
    convert "$file" \
      -resize 560 \
      "./out/blog/images/${NAME%.*}.jpg";
  fi
done

# Dither images
echo "Dithering images..."
for file in $BLOG_LOCATION/images/*; do
  NAME="$(basename "$file")"
  if [ ! -f "./out/blog/images/${NAME%.*}-grey.png" ]; then
    convert "$file" \
      -resize 560 \
      -alpha on \
      +dither \
      \( -size 2x2 xc:black -size 1x1 xc:white -gravity northwest -composite -write mpr:tile +delete \) \
      \( +clone -tile mpr:tile -draw "color 0,0 reset" \) \
      -alpha off -compose copy_opacity -composite \
      -set colorspace Gray \
      -colors 16 \
      "./out/blog/images/${NAME%.*}-grey.png";
  fi
done

# Create a table of contents
echo "Creating table of contents..."
TOC=()
for file in $BLOG_LOCATION/*.md; do
  NAME="$(basename "$file")"
  TITLE="$(grep "title:" "$file" | sed 's/[^ ]* //')"
  TOC+=("<a href='/blog/${NAME%-write.md}.html'>${NAME%-write.md} - $TITLE</a>")
done

TOCString=$(printf '%s' "${TOC[@]}")
sed -i -e "s|TOC|$TOCString|g" ./out/index.html

# Deploy to AWS
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
fi

echo "Done!"
