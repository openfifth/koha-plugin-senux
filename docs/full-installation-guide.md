SENUX is designed to be lightweight and easy to use. This guide will go through, in simple steps, all the things you need to do in order to install the plugin. This may include some things you do not necessarily have access to, so if there are any steps you don't understand, it is best to get in touch with your hosting provider, and ask them to run through this document.

## Enabling plugins

Koha's plugin system is turned off by default. You can check to see if it is on, by navigating to the Koha Administration page, and by finding the Manage Plugins option. If you can't find it, the `enable_plugins` option is likely set to `0` in the `koha-conf.xml` file. Set this to `1` and run `sudo koha-plack --restart <sidecode>` on the server's command-line (or, ask your hosting provider to do this for you).

If you find that you can access Manage Plugins, but the Upload button is missing, you'll likely also need to flip `plugins_restricted` from `1` to `0`, also in `koha-conf.xml`. Do this now, or ask your hosting provider to do so in your stead.

Lastly, it may also be wise to set `plugins_restart` to `1`, whilst you are editing the `koha-conf.xml` file. You'll need to do this in order to allow for a graceful restart of Koha after a plugin, which SENUX requires before it will work correctly. Again, make sure you run `sudo koha-plack --restart <sitecode>` on the server's command line (or, ask your hosting provider to do this for you).

## Installing SENUX

Once the plugin system for your Koha instance is enabled, you can install the plugin. [Go to the releases page](https://github.com/openfifth/koha-plugin-senux/releases), and find within the latest release. At the time of writing, this is v25.11.01. There will be three files; two source code archives, and a file ending in `.kpz`. Download this latter file.

Next, on your Koha system's Staff client, navigate to Koha Administration, then Manage Plugins. On this page, click Upload plugin. On the new page that appears, use the file picker to find your plugin, then click Upload. After a few seconds, you should be redirected back to the previous Manage Plugins page.

**Note:** If you were unable to switch `plugins_restart` to `1`, you'll need to restart Plack at this stage. If you can't do this yourself, contact your hosting supplier.

SENUX is now installed! Visit your OPAC, and you should see your lovely new OPAC!
