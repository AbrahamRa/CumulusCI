Key Concepts
============

The Product Delivery Model
-----------------------------
CumulusCI extends the concepts of the `Org Development Model <https://trailhead.salesforce.com/en/content/learn/modules/org-development-model>`_ and the `Package Development Model <https://trailhead.salesforce.com/en/content/learn/modules/sfdx_dev_model>`_ to form a new model, which we call the Product Delivery Model.

The Product Delivery Model focuses on the customer experience, not on the technical artifacts you're delivering, and focuses on making it possible to deliver a first-class, fully configured customer experience – no matter how complex the product might be. When building a product, there can be detailed technical considerations for whether a specific component is best distributed within a package, as additional unpackaged metadata, or as sophisticated setup automation that runs before or after a package is installed. And, of course, a product may include not one, but several packages, which must be installed in sequence. CumulusCI makes it possible to deliver a cohesive product that makes use of these different techniques.

CumulusCI automation, which makes it easy to create products that span multiple package repositories and include complex setup operations, is how we implement the Product Delivery Model throughout the development lifecycle. We also use MetaDeploy and other applications in the CumulusCI Suite to harness CumulusCI automation as we deliver products directly to customers.

The Product Delivery Model aims to represent a holistic view of delivery of a product instead of simply releasing a package. Here's a real-world example drawn from Salesforce.org's product portfolio.

The Nonprofit Success Pack and the Product Delivery Model
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

The Nonprofit Success Pack, or NPSP, is one of Salesforce.org's flagship products. The NPSP consists of six managed packages, with complex dependency relationships between them, alongside unpackaged metadata and setup automation that helps create a usable NPSP org.

Salesforce.org delivers NPSP using CumulusCI and the Product Delivery Model because those tools are what make it possible for us to ship this large, complex, heterogeneous application efficiently to tens of thousands of customers — without a lengthy setup guide to be completed by the end user. CumulusCI automation seamlessly

* deploys NPSP's five dependent managed packages in the right sequence;
* delivers unpackaged Record Types for the Account and Opportunity objects;
* installs NPSP;
* and performs final configuration to make the customer's experience better, like setting up Global Actions and delivering translations.

CumulusCI runs this automation throughout our development lifecycle, starting from feature branches in the hands of our developers and culminating in the delivery of new versions of the application to our users, including through MetaDeploy — which runs the very same automation we use internally to set up and configure a customer org.

Throughout the CumulusCI documentation, we'll have the Product Delivery Model in mind. 

Projects
--------

When you work with CumulusCI, you do so inside a project. A project is a version control repository that contains Salesforce metadata as well as the CumulusCI automation that builds and releases the project. A project usually has a one-to-one relationship with a managed package, if building a package, or with an org implementation. A project may constitute the entirety of a product in the Product Delivery Model, or may be one of multiple projects making up a product.

CumulusCI scopes many of its activities to the project, so you'll always run your CumulusCI commands inside your repository directory. Each project gets its own keychain, which we'll talk about in detail below. Each project has its own set of scratch orgs, which CumulusCI namespaces in the Salesforce CLI keychain to prevent collisions. And each project is linked to a single GitHub repository, so you can always be confident of the scope of the actions you're taking.

CumulusCI knows which project you are working on by the current working directory of your shell. Make sure to change directories inside your project before you run project-specific commands.

In order to be used as a CumulusCI project, a directory must both be a Git repository and contain a ``cumulusci.yml`` configuration file.

Managing Orgs & Services with the Keychain
------------------------------------------

CumulusCI gives each project a keychain, and also offers a global keychain that's shared across projects. The keychain's role is to store access information for all of the orgs you're using with the project — both scratch orgs and persistent orgs — and the details of the services you've connected, such as a GitHub account or an instance of MetaDeploy.

Orgs
++++

Each project's keychain stores authentication information for all of the orgs that are in use by the project, including scratch orgs, persistent orgs like a production or packaging org, and information about scratch orgs that are yet to be created.

The ``cci org list`` command shows all of the connected orgs in the project keychain, as well as defined scratch org configurations that have not yet been built. (TODO: reference org configuration section).

When CumulusCI builds a scratch org, it automatically shares the org with your Salesforce CLI keychain, but names the org in a way that helps keep orgs separate between projects. For example, if you build a ``dev`` org in the project ``Test``, CumulusCI will call that org ``dev`` in your CumulusCI keychain, and ``Test__dev`` in the Salesforce CLI keychain. This prevents your scratch orgs from colliding across projects.

CumulusCI stores org authentication details in an encrypted file in your configuration directory.

Configuring orgs in CumulusCI is powerful, but comes with some complexity. To review all of the details, read the section TODO: Reference "Scratch org environments".

Services
++++++++


Services represent external resources used by CumulusCI automation that are not project-specific orgs, such as access to a GitHub account or a MetaDeploy instance. Services are usually, but not always connected to CumulusCI across projects, and live in the global keychain. 

The command ``cci service list`` shows you which services are connected in the context of the current project.

Some services can be connected at the project level, which means that they're scoped to a single project and aren't shared. We recommend primarily using global services because they're easier to use, but you may encounter scenarios where, for example, you need to use a specific Dev Hub for one and only one project. Connecting that service with ``cci service connect devhub --project`` supports that use case.

CumulusCI stores service authentication details in an encrypted file in your configuration directory.

Tasks and Flows
---------------

CumulusCI uses a framework of *tasks* and *flows* to organize the automation that is available to each project.

Tasks are units of automation. A task could perform a deployment, load a dataset, retrieve material from an org, install a managed package, or undertake many other activities. CumulusCI ships with scores of tasks out of the box. 

You can review the tasks available in a project by running ``cci task list``, learn more about a task and how to configure its options with ``cci task info <name>``, where ``<name>`` is the name of the task, and run a task with ``cci task run <name> --org <org>``, where ``<name>`` is the name of the task and ``<org>`` is the org you'd like to run it against. For example, the ``run_tests`` task executes Apex unit tests. If you have an org called ``dev``, you can run this task against this org with the command ``cci task run run_tests --org dev``.

Many operations that you'll undertake with CumulusCI, including creating new orgs, use flows. Flows are ordered sequences of tasks (and other flows!) that produce a cohesive outcome, such as an org that's configured to suit a specific workflow. 

Find the list of flows available in a project by running ``cci flow list``. Learn more about a flow and the tasks it contains with ``cci flow info <name>``, where ``<name>`` is the name of the flow, and run a flow with ``cci flow run <name> --org <org>``, where ``<name>`` is the name of the flow and ``<org>`` is the org you'd like to run it against.

Many of the most common flows you'll work with in CumulusCI are designed to build and configure specific orgs for you. Here's a few of the most common flows that build orgs:

* ``dev_org``: This is an unmanaged org that is designed for development use. This flow is typically used with an org whose configuration is ``dev`` or ``dev_namespaced``.
* ``qa_org``: This is an unmanaged org that is designed for testing. This flow is typically used with an org whose configuration is ``qa``.
* ``install_beta``: This is a managed org with the latest beta release installed, for projects that build managed packages. This flow is typically used with an org whose configuration is ``beta``.
* ``install_prod``: This is a managed org with the latest release installed, for projects that build managed packages. 
* ``regression_org``: This is a managed org that starts with the latest release installed and is then upgraded to the latest beta to simulate a subscriber upgrade, for projects that build managed packages. This flow is typically used with an org whose configuration is ``release``.

CumulusCI derives the library of flows and tasks available for any project by combining its internal, out-of-the-box library with the customizations in ``cumulusci.yml``. Customizations can add new tasks and flows, customize the way out-of-the-box tasks behave, and extend, combine, and modify out-of-the-box flows to suit the specific needs of the project. We cover customization in depth in TODO: reference "Customizing CumulusCI"
