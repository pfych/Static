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
TIMEZONE=$(date +"%z")
RSS_TIME="00:00:00"

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
cp src/rss.xml out/
cp src/fonts/* out/fonts
find src/ -name '*.scss' -exec sass {} ./out/bundle.css \;
find src/ -name '*.ts' -exec tsc {} --outfile ./out/bundle.js \;

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
  TITLE="$(grep "^title:" "$file" | sed 's/[^ ]* //')"
  DRAFT="$(grep "^draft:" "$file" | sed 's/[^ ]* //')"

  if [ ! "$DRAFT" ]; then
    TOC+=("<a href='/blog/${NAME%$FILE_PREFIX.md}.html'>${NAME%$FILE_PREFIX.md} - $TITLE</a>")
  fi
done
TOCString=$(printf '%s' "${TOC[@]}")
sed -i -e "s|TOC|$TOCString|g" ./out/index.html

# Create RSS feed
RSS_ITEMS=()
echo "Creating RSS feed..."
cd "$BLOG_LOCATION"
for file in $BLOG_LOCATION/*.md; do
  NAME="$(basename "$file")"
  TITLE="$(grep "^title:" "$file" | sed 's/[^ ]* //')"
  EDIT_TIME="$(git log -1 --pretty="format:%ci" "$file" | cut -d" "  -f2,3)"
  PUB_DATE="$(date -d"${NAME%$FILE_PREFIX.md}" +"%a, %d %b %Y ${EDIT_TIME:-$RSS_TIME}")"
  DRAFT="$(grep "^draft:" "$file" | sed 's/[^ ]* //')"
  GUID="$(echo "$FILENAME $PUB_DATE" | md5sum | cut -f1 -d" ")"

  FILE_CONTENT=$(cat "${PARENT_PATH}out/blog/${NAME%$FILE_PREFIX.md}.html")
  FIXED_IMAGES=$(echo "$FILE_CONTENT" | sed "s/<img src=\"\./<img src=\"https:\/\/pfy\.ch\/blog/g" )
  FIXED_QUOTES=$(echo "$FIXED_IMAGES" | sed "s/\“/\"/g" | sed "s/\”/\"/g" | sed "s/\’/\'/g")
  FIXED_FILE="${FIXED_QUOTES#*</h1>}"

  if [ ! "$DRAFT" ]; then
    RSS_ITEMS+=("
      <item>
        <guid isPermaLink='false'>${GUID}</guid>
        <title>${TITLE}</title>
        <link>https://${DOMAIN_NAME}/blog/${NAME%$FILE_PREFIX.md}.html</link>
        <description><![CDATA[${FIXED_FILE%<\hr />*}]]></description>
        <author>pfych</author>
        <pubDate>${PUB_DATE}</pubDate>
      </item>
    ")
  fi
done
cd "$PARENT_PATH"
RSS_STRING=$(printf '%s' "${RSS_ITEMS[@]}" | tr -d '\n')
RSS_OUTPUT="<?xml version='1.0' encoding='ISO-8859-1' ?>
<rss version='2.0' xmlns:atom='http://www.w3.org/2005/Atom'>
  <channel>
    <title>pfy.ch</title>
    <link>https://pfy.ch</link>
    <description>pfych blogs</description>
    <atom:link href='https://pfy.ch/rss.xml' rel='self' type='application/rss+xml' />
    $RSS_STRING
  </channel>
</rss>"
echo "$RSS_OUTPUT" > ./out/rss.xml

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
