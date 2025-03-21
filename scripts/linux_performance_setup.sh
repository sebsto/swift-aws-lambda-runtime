#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the SwiftAWSLambdaRuntime open source project
##
## Copyright (c) 2020 Apple Inc. and the SwiftAWSLambdaRuntime project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

# docker run --privileged -it -v `pwd`:/code -w /code swiftlang/swift:nightly-5.3-bionic bash

apt-get update -y
apt-get install -y vim htop strace linux-tools-common linux-tools-generic libc6-dbg

echo 0 > /proc/sys/kernel/kptr_restrict

pushd /usr/bin || exit 1
rm -rf perf
ln -s /usr/lib/linux-tools/*/perf perf
popd || exit 1

pushd /opt || exit 1
git clone https://github.com/brendangregg/FlameGraph.git
popd || exit 1

# build the code in relase mode with debug symbols
# swift build -c release -Xswiftc -g
#
# run the server
# (.build/release/MockServer) &
#
# strace
# export MAX_REQUESTS=10000 (or MAX_REQUESTS=1 for cold start analysis)
# strace -o .build/strace-c-string-$MAX_REQUESTS -c .build/release/StringSample
# strace -o .build/strace-ffftt-string-$MAX_REQUESTS -fftt .build/release/StringSample
#
# perf
# export MAX_REQUESTS=10000 (or MAX_REQUESTS=1 for cold start analysis)
# perf record -o .build/perf-$MAX_REQUESTS.data -g -F 100000 .build/release/StringSample dwarf
# perf script -i .build/perf-$MAX_REQUESTS.data | /opt/FlameGraph/stackcollapse-perf.pl | swift-demangle | /opt/FlameGraph/flamegraph.pl > .build/flamegraph-$MAX_REQUESTS.svg
