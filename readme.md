Magento Boilerplate
================
This repository contains a bunch of stuff to make developing Magento themes and modules locally a little less stressful (in theory). With just one command you'll have a custom local development stack and Magento installation to start your new project on.

What's in the box?
----------------------
- **Vagrant** - Custom virtual LAMP stacks, automatically provisioned to your requirement (via VirtualBox)
- **n98-magerun** - CLI for Magento backend, also add's some additional database admin features. It's a bit like Drush for Drupal.
- **Modman** - Keep all your project files and dependencies away from Magento core
- **Foundation 5** - Responsive framework with support back to IE9 (via waterlee-boilerplate)
- **Gulp** - JS task runner to complie SCSS/JS, Lint, Copy, etc (via waterlee-boilerplate)

Phew, no sign of Gwyneth's head so far, Brad will be plaesed..

********************
**** Requirements ****
To get the local environment running you will need to install the following onto the host machine (your computer).
- [Git](https://msysgit.github.io/) - Install latest stable
- [Vagrant](https://www.vagrantup.com/) - Install latest stable
-  [VirtualBox](https://www.virtualbox.org/) - Install latest stable

By default Vagrant creates a shared drive to sync files between the host and guest machines uses it's own file system. Although this works very well out of the box for small projects it's is just too slow for Magento. Due to the number files involved in requesting a Magento page, a page reload can take well over 20 seconds on a quad-core host and guest!

To get round this we instead allow the host and guest to use their own native file systems.
Then we then watch our host directories and use Rsync write only modified files to the guest.
Rsync isn't available as a stand-alone service on windows, but you can add it to your Cygwin environment and vagrant will find it.

Cygwin is an environment which effectively provides unix tools to a windows system. If you don't have it installed then you can find it at the link below however you don't need everything selected during installation! Use the search to find the components which deal with rsync and ssh

- [Cygwin)](https://cygwin.com/install.html) - only Rsnyc & SSH related components required

*********************

First things first...
------------------------
Check you have installed the dependencies above!

I've Installed the dependancies, now what?
---------------------------------------------------
Nice one. The next step is to get the contents of this repository into a new repository for your own project. The way we do this is clone the repository locally, change the clones remote origin to a new remote for the project, and push our commits there instead. Follow the steps below and read carefully to prevent mistakes...

If you haven't already done so, clone this repository cd into it.
```
# Clone the boilerplate repository
git clone https://ems-internet.git.beanstalkapp.com/magento-workflow.git MY_PROJECT
# cd to the new repository
cd MY_PROJECT
```
Set the remote URL of the clones origin to the projects remote repository (probably a bare repository on beanstalk).
```
# Change the remote URL
git remote set-url origin https://ems-internet.git.beanstalkapp.com/NEW-REPOSITORY.git
```
And check it worked
```
# Verify new remote URL
git remote -v
```
```
# Should output sometihng like this
origin  https://ems-internet.git.beanstalkapp.com/NEW-REPOSITORY.git (fetch)
origin  https://ems-internet.git.beanstalkapp.com/NEW-REPOSITORY.git (push)
```
You should now have a new local repository full of boilerplate files linked to your projects empty remote repository, a simple git push to origin will now push the commit history to the remote. The 'all' flag makes sure all branches are push and not just the current one.
```
# Initial push
git push origin --all
```
High five!

Configuring Magento
-------------------------
Before you initialise your virtual machine for the first time you'll probably want to change a few of the default Magento settings. For convenience, you will also find  the most common settings in this file:

> /conf/n98-magerun.yaml

If you need to change anything else, the magento installation bash script can be found here:
>/bin/vagrant-magento.sh

If you do change stuff don't forget to comment your changes so that other people can find out what's different and why easily

Configuring Vagrant
------------------------
The 'vagrantfile' is essentially a list of instructions which tell's Vagrant how to build the virtual machine and link it into your computer. There are loads of settings which you can alter/add to optimise and change the way this works, however the settings provided will get you where you want to be for now.

Configuring your PC (not 'nix)
-----------------------------------
This stuff  may or may not need to be done, I was going to put it up with with the prerequisites but some stuff's optional, some stuff there may be a better way of doing and some stuff may have only been an issue for me. However one's things for sure, it all only applies to windows host :)

Anyway you should check this lot over, it may save your knuckles from turning white...

**Enable hardware virtualisation**
In order to run a 64bit virtualbox I had to enable this feature from my BIOS, I would recomend you check this is enabled on yours sooner rather than later. Your BIOS may well be different to mine so I can't really help you anymore than [this](https://www.google.co.uk/?#q=Enable+hardware+virtualisation)

**Enable symlinks on windows**
By default only  the local admins can create symlinks on windows. You want to give your user the rights to do this too so any programs it runs can also do this.

- Open the Microsoft Management Console by hitting `[win] + R`,  type `mmc` and punch OK
- Select 'Local Computer Policy' (If you can't see it on the left add the 'Group Policy' snap-in from the file menu
- Navigate to `Computer configuration | Windows Settings | Security Settings | Local Policies | User Rights Assignment | Create symbolic links`, right click and edit the properties
- Click 'Add User or Group, enter your name and click 'Check Names'.
- OK/Apply you way back out of there.

**Add 'Open command prompt as admin' to context menu**
You're gonna want to open cmd prompts in random directories, you're also gonna want the programs you run inside them to have admin rights. You're gonna probably going to want this to be as simple as possible every time.

Create a new file and paste this into it:

```
Windows Registry Editor Version 5.00

[-HKEY_CLASSES_ROOT\Directory\shell\runas]

[HKEY_CLASSES_ROOT\Directory\shell\runas]
@="Open command window here as Administrator"
"HasLUAShield"=""

[HKEY_CLASSES_ROOT\Directory\shell\runas\command]
@="cmd.exe /s /k pushd \"%V\""

[-HKEY_CLASSES_ROOT\Directory\Background\shell\runas]

[HKEY_CLASSES_ROOT\Directory\Background\shell\runas]
@="Open command window here as Administrator"
"HasLUAShield"=""

[HKEY_CLASSES_ROOT\Directory\Background\shell\runas\command]
@="cmd.exe /s /k pushd \"%V\""

[-HKEY_CLASSES_ROOT\Drive\shell\runas]

[HKEY_CLASSES_ROOT\Drive\shell\runas]
@="Open command window here as Administrator"
"HasLUAShield"=""

[HKEY_CLASSES_ROOT\Drive\shell\runas\command]
@="cmd.exe /s /k pushd \"%V\""
```

Save the file as `add_to_context_cmd_admin.reg` in a temporary location and double click the saved file to update the system registry

You should now have the new option in you context menu when you right click in file explorer.

**Other PC configuration brain-melters**
If you find something I've missed please add it to this list so other people don't have to share in your misfortune and undue pain.

Pushing the button
-----------------------

Ok then, are you ready to rock and/or roll? Commit any changes you have made to the dev branch in your and hold on to your socks...

>Open a Command Prompt as Admin in the root of your repository

There's a shell script in there called `'up'` which acts as a wrapper for Vagrants CLI and will trigger `vagrant up` along with a few other things we'll learn about later.

```
vagrant up
```
If all goes well Vagrant will provision the virtualbox guest for you and at the end trigger the Rsync-auto tasks which will watch for local file changes. You should see something like this

```
Now running rsync in the background (pid=6616).
[L] Login via SSH
[H] Halt
[S] Suspend
[R] Restart rsnyc-auto watcher
[P] Provision
> ==> default: Doing an initial rsync...
==> default: Rsyncing folder: /cygdrive/c/Users/richardjesudason/Magento/magento-workflow-new/src/ => /home/va
grant/src
==> default:   - Exclude: [".vagrant/", ".git/", ".settings/", "node_modules/", "bower_components/", "themes/*
/skin/css/", "themes/*/skin/js/"]
==> default: Rsyncing folder: /cygdrive/c/Users/richardjesudason/Magento/magento-workflow-new/.modman/ => /hom
e/vagrant/.modman
==> default:   - Exclude: [".vagrant/", ".git/", "/src"]
==> default: Rsyncing folder: /cygdrive/c/Users/richardjesudason/Magento/magento-workflow-new/vendor/ => /home
/vagrant/vendor
==> default:   - Exclude: [".vagrant/", ".git/"]
==> default: Watching: C:/Users/richardjesudason/Magento/magento-workflow-new/.modman
==> default: Watching: C:/Users/richardjesudason/Magento/magento-workflow-new/src
==> default: Watching: C:/Users/richardjesudason/Magento/magento-workflow-new/vendor
D, [2015-04-30T17:09:32.216588 #8124] DEBUG -- : Adapter: considering TCP ...
D, [2015-04-30T17:09:32.217565 #8124] DEBUG -- : Adapter: considering polling ...
D, [2015-04-30T17:09:32.217565 #8124] DEBUG -- : Adapter: considering optimized backend...
```

> Written with [StackEdit](https://stackedit.io/).