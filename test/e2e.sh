#!/bin/bash -xe
docker run -v `pwd`:/src gcr.io/kubernetes-charts-ci/test-image:v1.2 /src/test/test_changed.sh
echo "Done Testing!"
