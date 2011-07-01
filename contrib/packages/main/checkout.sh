#!/bin/bash

date=`date +"%Y%m%d"`
name="scalaris-svn" # folder base name (without version)
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
  mv "${folder}" "${newfoldername}" && tar -czf ${tarfile} ${newfoldername} --exclude-vcs && mv "${newfoldername}" "${folder}"
  result=$?
fi

if [ ${result} -eq 0 ]; then
  echo "extracting .spec file ..."
  sourcefolder=${folder}/contrib/packages/main
  sed -e "s/%define pkg_version .*/%define pkg_version ${revision}/g" \
      < ${sourcefolder}/scalaris-svn.spec              > ./scalaris-svn.spec && \
  cp  ${sourcefolder}/scalaris-svn-rpmlintrc             ./scalaris-svn-rpmlintrc
  result=$?
fi

if [ ${result} -eq 0 ]; then
  echo "extracting Debian package files ..."
  sourcefolder=${folder}/contrib/packages/main
  sed -e "s/Version: 1-1/Version: ${revision}-1/g" \
      -e "s/scalaris-svn\\.orig\\.tar\\.gz/scalaris-svn-${revision}\\.orig\\.tar\\.gz/g" \
      -e "s/scalaris-svn\\.diff\\.tar\\.gz/scalaris-svn-${revision}\\.diff\\.tar\\.gz/g" \
      < ${sourcefolder}/scalaris-svn.dsc               > ./scalaris-svn.dsc && \
  sed -e "s/(1-1)/(${revision}-1)/g" \
      < ${sourcefolder}/debian.changelog               > ./debian.changelog && \
  cp  ${sourcefolder}/debian.control                     ./debian.control && \
  cp  ${sourcefolder}/debian.rules                       ./debian.rules && \
  cp  ${sourcefolder}/debian.scalaris-svn.files          ./debian.scalaris-svn.files && \
  cp  ${sourcefolder}/debian.scalaris-svn.conffiles      ./debian.scalaris-svn.conffiles && \
  cp  ${sourcefolder}/debian.scalaris-svn.postrm         ./debian.scalaris-svn.postrm && \
  cp  ${sourcefolder}/debian.scalaris-svn.postinst       ./debian.scalaris-svn.postinst && \
  cp  ${sourcefolder}/debian.scalaris-svn-doc.files      ./debian.scalaris-svn-doc.files
  result=$?
fi

if [ ${result} -eq 0 -a ${deletefolder} -eq 1 ]; then
  echo "removing ${folder} ..."
  rm -rf ${folder}
fi
