# Custom Connector Sample from Microsoft Ignite 2018

This custom connector was created for the [Microsoft Ignite 2018](https://channel9.msdn.com/Events/Ignite/2018) event. It demonstrates how a custom connector can be used to provide an analyst friendly connector with custom branding for an internal data source.

## Environment requirements

- Local SQL Server instance
- [WideWorldImportersDW](https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0)
- SQL Server Native Client ODBC 11.0

The custom connector assumes the `WideWorldImportersDW` database is available on `localhost` sql server instance. To change these settings, update the hard coded values in
the .pq connector file.

Icon adapted from: https://commons.wikimedia.org/wiki/File:Blue_globe_icon.svg
Power BI report adapted from: https://github.com/Microsoft/sql-server-samples/tree/master/samples/databases/wide-world-importers/power-bi-dashboards