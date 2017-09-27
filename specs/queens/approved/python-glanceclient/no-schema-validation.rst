===============================================
Spec Lite: Switch to Turn Off Schema Validation
===============================================

:problem: While an API is in EXPERIMENTAL status, the schemas may not
          accurately reflect the content of requests and responses,
          causing the client to error out.

:solution: Introduce a new option controlled by an environment variable
           that will turn off schema validation.

:impacts: None

:timeline: Q-1 milestone (week of 16 October 2017)

:link: https://blueprints.launchpad.net/python-glanceclient/+spec/no-schema-validation

:reviewers: all core reviewers
