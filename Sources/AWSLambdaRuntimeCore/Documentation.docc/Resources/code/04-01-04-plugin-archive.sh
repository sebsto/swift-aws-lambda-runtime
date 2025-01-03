swift package archive --allow-network-connections docker

-------------------------------------------------------------------------
building "palindrome" in docker
-------------------------------------------------------------------------
updating "swift:amazonlinux2" docker image
  amazonlinux2: Pulling from library/swift
  Digest: sha256:df06a50f70e2e87f237bd904d2fc48195742ebda9f40b4a821c4d39766434009
Status: Image is up to date for swift:amazonlinux2
  docker.io/library/swift:amazonlinux2
building "PalindromeLambda"
  [0/1] Planning build
  Building for production...
  [0/2] Write swift-version-24593BA9C3E375BF.txt
  Build of product 'PalindromeLambda' complete! (1.91s)
-------------------------------------------------------------------------
archiving "PalindromeLambda"
-------------------------------------------------------------------------
1 archive created
  * PalindromeLambda at /Users/sst/Palindrome/.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/PalindromeLambda/PalindromeLambda.zip

cp .build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/PalindromeLambda/PalindromeLambda.zip ~/Desktop
