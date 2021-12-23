# Static
This repo is the code that powers the website [pfy.ch](https://pfy.ch).

## Requires:
- `pandoc`
- `sass`
- `aws-cli` (Optional)

```
yay -Syu pandoc sass aws-cli
```

## Build:
- Edit `build.sh` and replace `$BLOG_LOCATION` with a path to your markdown files.
- Edit (or remove) aws s3 deployment

`/out` will contain the static site. The script will try push this folder to an S3 bucket.
