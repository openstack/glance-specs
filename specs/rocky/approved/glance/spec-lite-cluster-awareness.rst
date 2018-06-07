..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

===================================
Spec Lite: Glance cluster awareness
===================================

..
  Mandatory sections

:project: glance

:problem: Individual glance nodes are fully un-aware that there might be
          other nodes operating in the same space. This lack of communication
          between the nodes causes issues separating workers and operating in
          different locations.

:solution: We have message queues already utilized in notifications and other
           projects. Lets expand that for communications between different
           glance-api nodes to gain better operational efficiency.

:impacts: DocImpact

..
  Optional sections -- delete any that don't apply to this spec lite

:alternatives: We could use something else than the message queues but
               effectively that would end up recreating something like registry
               but just as a message broker.

:timeline: Possible initial functionality in Rocky, more use cases covered S
           and beyond. This can be expanded fairly easily so we can proceed as
           time permits.

:assignee: jokke
