.. _train-priorities:

========================
Train Project Priorities
========================

Top priorities for Glance in Train cycle are:

* Release glance_store 1.0.0
* Getting multi-store moved away from Experimental
* Removing dependencies to registry from cache tooling
* Cleaning up deprecations
* Cluster awareness:

  * Image import call rerouting to the node that has access to image in staging
  * Centralized cache management via API endpoint:

    * Listing cached images across cluster
    * Precaching images

  * Copy/Remove images cross multi-store
  * Distributed Store Discovery

On top of these housekeeping and feature items the community will prioritize
bugfixes and reviews as appropriate.
