#!/usr/bin/env bash
# shellcheck disable=SC2231

shopt -s failglob

###############
# USER CONFIG #
###############

export AWS_REGION='ap-southeast-2'
BLOG_LOCATION=/home/pfych/Documents/Scratchpad-write
DOMAIN_NAME='pfy.ch'
DOMAIN_BASE='www'
# We assume filename will be YY-MM-DD-FILE_PREFIX.md (ie. 21-12-20-write.md)
FILE_PREFIX='-write' 
# What time of day should RSS report?
RSS_TIME='00:00:00 AEST'

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
cp src/index.html out/
cp src/404.html out/
cp src/rss.xml out/
find src/ -name '*.scss' -exec sass {} ./out/bundle.css \;

# Compile Blogs
echo "Running pandoc..."
for file in $BLOG_LOCATION/*.md; do
  NAME="$(basename "$file")"
  pandoc "$file" -o ./out/blog/"${NAME%$FILE_PREFIX.md}".html --template ./src/blog/index.html
done

# Create a table of contents
echo "Creating table of contents..."
TOC=()
for file in $BLOG_LOCATION/*.md; do
  NAME="$(basename "$file")"
  TITLE="$(grep "title:" "$file" | sed 's/[^ ]* //')"
  DRAFT="$(grep "draft:" "$file" | sed 's/[^ ]* //')"
  
  if [ ! $DRAFT ]; then
    TOC+=("<a href='/blog/${NAME%$FILE_PREFIX.md}.html'>${NAME%$FILE_PREFIX.md} - $TITLE</a>")
  fi
done

TOCString=$(printf '%s' "${TOC[@]}")
sed -i -e "s|TOC|$TOCString|g" ./out/index.html

# Create RSS feed
RSS_ITEMS=()
echo "Creating RSS feed..."
for file in $BLOG_LOCATION/*.md; do
  NAME="$(basename "$file")"
  TITLE="$(grep "title:" "$file" | sed 's/[^ ]* //')"
  DESCRIPTION="$(grep "summary:" "$file" | sed 's/[^ ]* //')"
  PUB_DATE="$(date -d"${NAME%$FILE_PREFIX.md}" +"%A, %d %b %Y $RSS_TIME")"
  DRAFT="$(grep "draft:" "$file" | sed 's/[^ ]* //')"
  
  if [ ! $DRAFT ]; then
    RSS_ITEMS+=("
      <item>
        <title>${TITLE}</title>
        <link>https://${DOMAIN_NAME}/blog/${NAME%$FILE_PREFIX.md}.html</link>
        <description>${DESCRIPTION:-$TITLE}</description>
        <pubDate>${PUB_DATE}</pubDate>
      </item>
    ")
  fi
done
RSS_STRING=$(printf '%s' "${RSS_ITEMS[@]}" | tr -d '\n')
sed -i -e "s|RSS_PLACEHOLDER|$RSS_STRING|g" ./out/rss.xml

# Move images
echo "Resizing images..."
for file in $BLOG_LOCATION/images/*; do
  NAME="$(basename "$file")"
  if [ ! -f "./out/blog/images/${NAME%.*}.jpg" ]; then
    echo "Resizing: $file"
    convert "$file" \
      -resize 720 \
      "./out/blog/images/${NAME%.*}.jpg";
  fi
done

# Dither images
echo "Dithering images..."
for file in $BLOG_LOCATION/images/*; do
  NAME="$(basename "$file")"
  if [ ! -f "./out/blog/images/${NAME%.*}-grey.png" ]; then
    echo "Dithering $file"
    convert "$file" \
      -resize 720 \
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

# Deploy to AWS
#echo "Deploying..."
#aws s3 sync "$PARENT_PATH/out/" s3://$BUCKET_NAME/
#aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy "$POLICY"
#aws s3 website s3://$BUCKET_NAME/ --index-document index.html --error-document 404.html
#CLOUDFRONT_DISTRIBUTION_ID=$(aws cloudfront list-distributions | jq --arg domain "$BUCKET_NAME" '.DistributionList.Items | map(select(.Aliases.Items != null)) | map(select(.Aliases.Items[]  | contains ($domain))) | .[] .Id' | sed 's/"//g')
#if [ "${CLOUDFRONT_DISTRIBUTION_ID:-"_"}" == "_" ]; then
#  echo "No cloudfront cache"
#else
#  aws cloudfront create-invalidation --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" --paths "/*" >> /dev/null
#  echo "Invalidated cache"
#fi

echo "Done!"
