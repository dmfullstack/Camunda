Example of an external worker written in C# by calling Camunda REST APIs in an asynchronous fashion. 

For a more robust implementation of a C# client see <a href="https://www.nuget.org/packages/BerndRuecker.Sample.CamundaClient/" target="_blank">Bernd Ruecker's Sample C# Client</a>. Also, have a look at Bernd's showcase example on <a href="https://github.com/berndruecker/camunda-csharp-showcase" target="_blank">github</a>. 

Using REST, this example will look for jobs on a topic you provide when you start the client. Be sure to install the Newtonsoft JSON package to make use of this client - `dotnet add package Newtonsoft.Json --version x.x.x.x`. 

To run the client execute the following command - `dotnet run CSharpWorker.cs your_topic`

