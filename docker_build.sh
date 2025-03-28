#!/bin/bash

VERSION=$(jq -r .version package.json)
VERSION_TAG=$VERSION

docker build --build-arg skip_dev_deps=true -t unicorp/redash_oracle:$VERSION_TAG .

echo "Built: $VERSION_TAG"