FROM alpine

RUN apk add --no-cache jq curl bash

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]