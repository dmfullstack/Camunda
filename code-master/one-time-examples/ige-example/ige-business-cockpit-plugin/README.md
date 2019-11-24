Cockpit plugin with business data from some process instances
=============================================================

This Plugin shows two input search fields for business data, here special process variables.
After hitting the search button, the process instances which contains one of the search
criteria will be shown in the result table.

Built and tested against camunda BPM version `7.1.0-Final`.

![Screenshot][1]

How to use
----------------------

1. Build the plugin using maven with mvn clean install

2. Integrate the JAR in your camunda-*.war file and there under WEB-INF/lib

3. After starting the cockpit application it will be shown on the process definition screen.

[1]: https://raw.githubusercontent.com/camunda/camunda-consulting/master/one-time-examples/ige-example/ige-business-cockpit-plugin/screenshot.png "Screenshot"
