# Static
This repo is the code that powers the website [pfy.ch](https://pfy.ch).

## Requires:
- `pandoc`
- `sass` (optional)
- `tsc` (optional)
- `aws-cli` (Optional)

```sh
yay -Syu pandoc sass aws-cli
npm install -g typescript
```

## Build:
- Edit `build.sh` and replace `$BLOG_LOCATION` with a path to your markdown files.
- Edit (or remove) aws s3 deployment

`/out` will contain the static site. The script will try push this folder to an S3 bucket.

### Even plainer

Feel free to adjust the lines relating to `tsc` or `sass` as they are not required if using plain `CSS` or `Javascript`

```sh
# Replace these lines:
# find src/ -name '*.scss' -exec sass {} ./out/bundle.css \;
# find src/ -name '*.ts' -exec tsc {} --outfile ./out/bundle.js \;
cp src/*.js out/;
cp src/*.css out/;
```

The only **required** files in `src/` are:
- `/blog/index.html`
- `/404.html`
- `/index.html`
- `/rss.xml`

Everything else can be safely removed once references are deleted in related files.
