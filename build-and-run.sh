#!/bin/bash

mkdir build
cp src/* assets/* build/
cd build/
javac *.java
/usr/bin/java LemmingCanvas
cd -
rm -rf build
