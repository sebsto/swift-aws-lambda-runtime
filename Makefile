CONTAINER ?= docker
# CONTAINER=container make build-linux # Uses container command

doc:
	swift package generate-documentation --target AWSLambdaRuntime

preview:
	swift package --disable-sandbox preview-documentation --target AWSLambdaRuntime

generate:
	swift package --allow-writing-to-directory /Users/stormacq/Desktop/lambda-runtime-doc 	 \
    generate-documentation --target AWSLambdaRuntime  --disable-indexing                 \
    --output-path /Users/stormacq/Desktop/lambda-runtime-doc \
    --transform-for-static-hosting \
    --hosting-base-path lambda-runtime-doc

build-linux:
	$(CONTAINER) run --rm -v $$(pwd):/work swift:6.1 /bin/bash -c "cd /work && swift build && swift test"

build-linux-60:
	$(CONTAINER) run --rm -v $$(pwd):/work swift:6.0 /bin/bash -c "cd /work && swift build && swift test"

build-linux-nightly:
	$(CONTAINER) run --rm -v $$(pwd):/work swiftlang/swift:nightly-6.2-jammy /bin/bash -c "cd /work && swift build && swift test"

format:
	swift format format --parallel --recursive --in-place ./Package.swift Examples/ Sources/ Tests/

# how to dynamically add dependency to Package.swift

# for manifest in Package.swift Package@*.swift ; do
#     if ! grep -E -i "https://github.com/(apple|swiftlang)/swift-docc-plugin" "$manifest" ; then
#         cat <<EOF >> "$manifest"
#             package.dependencies.append(
#                 .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "\(version)")
#             )
#         EOF
#     fi
# done