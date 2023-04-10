#!/bin/bash

usage () {
    echo "Usage: $(basename $0) VERSION"
    exit 1
}

[[ "$#" -ne "1" ]] && usage

sed -i "s|priorities/.*|priorities/$1-priorities|;
/Current/,/specs/{
    /specs/ { h; s|specs/.*|specs/$1/*| }
};
/Past/,/specs/{
    /specs/{x;p;x }
}" doc/source/index.rst

cat <<EOF > "priorities/$1-priorities.rst"
.. _$1-priorities:

=========================
$1 Project Priorities
=========================

TODO(glance-ptl): fill this in after the PTG




EOF

mkdir -p specs/"$1"/approved/{glance,glance_store,python-glanceclient}
mkdir -p specs/"$1"/implemented

for project in glance glance_store python-glanceclient
do
    echo "../../../template.rst" > "specs/$1/approved/$project/template.rst"
    echo "../../../spec-lite-template.rst" > "specs/$1/approved/$project/spec-lite-template.rst"
done


cat <<EOF > "specs/$1/index.rst"
=====================
$1 Specifications
=====================

.. toctree::
   :glob:
   :maxdepth: 1

$1 implemented specs:

.. toctree::
   :glob:
   :maxdepth: 1

   implemented/*

$1 approved (but not implemented) specs:

.. toctree::
   :glob:
   :maxdepth: 1

   approved/*


EOF

cat <<EOF > "specs/$1/approved/index.rst"
==============================
$1 Approved Specifications
==============================

.. toctree::
   :glob:
   :maxdepth: 1

TODO: fill this in once a new approved spec is added.




EOF

cat <<EOF > "specs/$1/implemented/index.rst"
=================================
$1 Implemented Specifications
=================================

TODO: fill this in once a new implemented spec is added.




EOF
