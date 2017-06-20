---
layout: post
title: Flatpak, 7 days after
subtitle: Feedback, feeling & rock'n'roll
image: assets/flatpak/flatpak-header.png
tags:
  - Flatpak
  - Gnome
  - Continuous integration
  - Travis
  - Docker
  - Feedback
---

# ... and there is Flatpak

__[Flatpak](http://flatpak.org/)__ is

> the next-generation technology for building and installing desktop applications.
  It has the power to revolutionize the Linux desktop ecosystem.

Whoaa! Looks promising !

The project started to gain visibility from the end of the first half of 2016. According to Wikipedia, __[Flatpak](http://flatpak.org/)__ is

> a software utility for software deployment, package management, and application virtualization for Linux desktop computer

This last definition definitively catch the idea under __[Flatpak](http://flatpak.org/)__.

# Benefits

After playing a week with Flatpak, my first thoughts are :

* As I like to fully understand what's lye under the hood, `flatpak` concepts are a bit tricky to catch
* That `flatpak` command-line tool api could be improved

Short after, I got the gist, and everything was working well, as expected.

## Design, CI with _Travis_ and distribute a Vala application
(but it's true for any C or C++ application as well)

### Before Flatpak

Coding a (system) application while keeping compatibilty with a wide variery of runtimes and libraries - most of the time, it's done by using conditional FLAGS - is really time consuming. Sometimes it can't be avoid, sometimes it can. We can choose to __statically link__ these libraries with our application, but there's a lot of drawbacks which make the whole somewhat not predictable.

With Flatpack, Gnome runtimes contains a wide range of libraries freezed at a known and predictable version.

But I first came to __[Flatpak](http://flatpak.org/)__ with the idea to test the build of a Vala application against different versions of Gtk3+.

Doing this without __[Flatpak](http://flatpak.org/)__ is still possible with Docker, but would require one base image per Gtk3+ version.

On a project driven by a small team, it may be a right choice to build against only one targeted Gtk3+ version and do choices about wich Gtk version range to support. And it doesn't only concern Gtk3+, but all libraries that your project depends on.

And when it's time to distribute the application on a variety of Linux distributions, things became really handy.

Flapak to the rescue : it's where Flatpak is good at. Distribute and keep up-to-date our applications without thinking about dependencies.
If they build inside a Flatpak sandbox, they'll run in it.

### After Flatpak

I created a Docker image containing some __[Flatpak](http://flatpak.org/)__ basics, like remotes gnome repositories.

{% highlight Dockerfile%}
# Flatpak-gnome
#
# AUTHOR                Laurent Callarec<l.callarec@gmail.com>
# VERSION               0.0.2
FROM ubuntu:17.04

RUN apt-get update -y

# Install base dependencies
## For add-apt-repository binary
RUN apt-get install -y software-properties-common python-software-properties build-essential

# Install flatpak
RUN add-apt-repository ppa:alexlarsson/flatpak -y
RUN apt-get update -y
RUN apt install flatpak -y

# Install remote
RUN flatpak remote-add --if-not-exists gnome https://sdk.gnome.org/gnome.flatpakrepo

# Clean
RUN apt-get clean -y && apt-get autoclean -y

CMD ["/bin/bash"]
{% endhighlight %}

Then on travis, I have this project and this file :

{% highlight yml%}
---
dist: trusty
sudo: required

language: c

services:
  - docker

before_install:
  - docker pull lcallarec/flatpak-gnome

script:
  - docker run --privileged -v $PWD:/build:rw lcallarec/flatpak-gnome /bin/bash -c "cd /build && make"

{% endhighlight %}

{% highlight yml%}
{% endhighlight %}
