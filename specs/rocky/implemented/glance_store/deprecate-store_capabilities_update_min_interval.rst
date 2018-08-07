..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

===========================================================
Spec Lite: Deprecate store_capabilities_update_min_interval
===========================================================

:project: glance_store

:problem: The configuration option ``store_capabilities_update_min_interval``
          is confusing because no existing stores implement the
          StoreCapability.update_capabilities() method.  This has come up in
          the context of nfs being used for the filesystem backend.  If nfs
          is not ready for writing when the glance api starts, glance will
          mark the filesystem as not writeable.  Operators have tried to get
          around this problem by setting a non-zero positive value for this
          option only to find that it doesn't work.

:solution: Use oslo.config to mark the option as 'deprecated' with an
           appropriate note.  Option will be deprecated in Rocky for removal
           in 'S'.

:alternatives: An alternative would be to rewrite the option help text to make
               it clear that there is no current store for which the option is
               actionable, but that a framework is in place through which
               dynamic capability determination could be implemented.
               Currently a debug level message to this effect is logged on
               store startup although it is not obvious that the message is
               related to the ineffectiveness of setting the
               ``store_capabilities_update_min_interval`` option.  The message
               is: "Store %s doesn't support updating dynamic storage
               capabilities. Please overwrite 'update_capabilities' method of
               the store to implement updating logics if needed."  (This
               message is logged independently of setting the option.)

               The advantage to this approach is that the framework would be
               available to someone who wanted to implement dynamic updates
               for a store, and the option would not have to be re-introduced.

:impacts: None

:timeline: Rocky milestone 2

:assignee: rosmaita
