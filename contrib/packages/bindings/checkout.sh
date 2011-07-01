#!/bin/bash

date=`date +"%Y%m%d"`
name="scalaris-svn-bindings" # folder base name (without version)
url="http://scalaris.googlecode.com/svn/trunk/"
deletefolder=0 # set to 1 to delete the folder the repository is checked out to

#####

folder="./${name}"

if [ ! -d ${folder} ]; then
  echo "checkout ${url} -> ${folder} ..."
  svn checkout ${url} ${folder}
  result=$?
else
  echo "update ${url} -> ${folder} ..."
  svn update ${folder}
  result=$?
fi

if [ ${result} -eq 0 ]; then
  echo -n "get svn revision ..."
  revision=`svn info ${folder} --xml | grep revision | cut -d '"' -f 2 | head -n 1`
  result=$?
  echo " ${revision}"
  # not safe in other languages than English:
  # revision=`svn info ${name} | grep "Revision:" | cut -d ' ' -f 4`
fi

if [ ${result} -eq 0 ]; then
  tarfile="${folder}-${revision}.tar.gz"
  newfoldername="${folder}-${revision}"
  echo "making ${tarfile} ..."
  mv "${folder}" "${newfoldername}" && tar -czf ${tarfile} ${newfoldername} --exclude-vcs --exclude=${newfoldername}/src --exclude=${newfoldername}/test --exclude=${newfoldername}/include --exclude=${newfoldername}/contrib --exclude=${newfoldername}/user-dev-guide --exclude=${newfoldername}/doc --exclude=${newfoldername}/docroot && mv "${newfoldername}" "${folder}"
  result=$?
fi

if [ ${result} -eq 0 ]; then
  echo "extracting .spec file ..."
  sourcefolder=${folder}/contrib/packages/bindings
  sed -e "s/%define pkg_version .*/%define pkg_version ${revision}/g" \
      < ${sourcefolder}/scalaris-svn-bindings.spec     > ./scalaris-svn-bindings.spec
  result=$?
fi

if [ ${result} -eq 0 ]; then
  echo "extracting Debian package files ..."
  sourcefolder=${folder}/contrib/packages/bindings
  sed -e "s/Version: 1-1/Version: ${revision}-1/g" \
      -e "s/scalaris-svn-bindings\\.orig\\.tar\\.gz/scalaris-svn-bindings-${revision}\\.orig\\.tar\\.gz/g" \
      -e "s/scalaris-svn-bindings\\.diff\\.tar\\.gz/scalaris-svn-bindings-${revision}\\.diff\\.tar\\.gz/g" \
      < ${sourcefolder}/scalaris-svn-bindings.dsc      > ./scalaris-svn-bindings.dsc && \
  sed -e "s/(1-1)/(${revision}-1)/g" \
      < ${sourcefolder}/debian.changelog               > ./debian.changelog && \
  cp  ${sourcefolder}/debian.control                      ./debian.control && \
  cp  ${sourcefolder}/debian.rules                        ./debian.rules && \
  cp  ${sourcefolder}/debian.scalaris-java.files         ./debian.scalaris-svn-java.files && \
  cp  ${sourcefolder}/debian.scalaris-java.conffiles     ./debian.scalaris-svn-java.conffiles && \
  cp  ${sourcefolder}/debian.scalaris-java.postrm        ./debian.scalaris-svn-java.postrm && \
  cp  ${sourcefolder}/debian.scalaris-java.postinst      ./debian.scalaris-svn-java.postinst && \
  cp  ${sourcefolder}/debian.python-scalaris.files       ./debian.python-scalaris-svn.files && \
  cp  ${sourcefolder}/debian.python3-scalaris.files      ./debian.python3-scalaris-svn.files && \
  cp  ${sourcefolder}/debian.scalaris-ruby1.8.files      ./debian.scalaris-svn-ruby1.8.files
  result=$?
fi

if [ ${result} -eq 0 -a ${deletefolder} -eq 1 ]; then
  echo "removing ${folder} ..."
  rm -rf ${folder}
fi
