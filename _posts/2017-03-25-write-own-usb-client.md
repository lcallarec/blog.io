---
layout: post
title: Write your own USB client
subtitle: With Wireshark, Luxafor & Vala to the rescue
tags:
  - USB
  - Luxafor
  - Vala
  - Wireshark
---

<em id="tags-title">Tags :</em> {% for tag in page.tags %}<span id="tags-items">{{ tag }} {% endfor%} </span>

# Purposes

I'm sometimes using a __[Luxafor](http://www.luxafor.fr/products/)__ device at work, and I finally bought one for the fun - because I guess that there's something interesting to do with it. Luxafor only provides clients for _Macos_ and _Windows_, so I could write a **Luxafor** client for _Linux_, couldn't I ?

I knew that there was, at that time, at least two libraries, written for __[nodejs](https://github.com/iamthefox/luxafor)__ and for __[python](https://github.com/vmitchell85/luxafor-python)__. But that's not fun, the challenge is elsewhere :p

It doesn't look so hard, it's basically binary data sent over an USB device, isn't it ?

This start by installing an official client, plug the device into the USB port, and capture binary data sent from the client to the device.

Sadly, it's far much easier to sniff USB traffic on _Windows_ than on _Linux_, let's go on _Windows_.

# Sniff USB traffic (on Windows, but not really)

I thought that I'll install a Windows for that purpose, but I definitively abandoned that idea. No way. So, let's say there's an official Luxafor client for Ubuntu.

## Install Wireshark

{% highlight bash %}
$ sudo install wireshark
{% endhighlight %}

## Load usbmon Kernel module

{% highlight bash %}
$ sudo modprobe usbmon
{% endhighlight %}

## Start wireshark

{% highlight bash %}
$ sudo wireshark
{% endhighlight %}

## Find in which monitor the Luxafor is pluggued

When Wireshark starts, you'll see the live traffic on each interfaces that can be sniffed by the tool. The __usbmon2__ traffic pike matches exactly the time when I pluggued the device :

![interfaces]({{ site.url }}/assets/2017-03-25/wireshark-interfaces.png)

### Capture when I change the Luxafor color

__Double-click on usbmon2__

![Ready to listen]({{ site.url }}/assets/2017-03-25/wireshark-ready.png)

__Activate the Luxafor color RED__

For that purpose, consider [my own luxafor-cli written in Vala](https://github.com/lcallarec/luxafor-cli/), or try this [nodejs](https://github.com/iamthefox/luxafor) script else this [python](https://github.com/vmitchell85/luxafor-python) script.

{% highlight bash %}
$ sudo ./luxafor color --red=255
{% endhighlight %}

__Analyze the payload__

When the Luxafor change to red, Wireshark has sniffed you packets :

![Sniff]({{ site.url }}/assets/2017-03-25/wireshark-sniff.png)

The most important information is the URB_INTERUPT packet sent from host to USB device. The leftover capture data are the actual data that have been sent to the USB device.

{% highlight R %}
01 ff ff 00 00 00 00
{% endhighlight %}

Bingo !

* The packet sent is seven 8-bits data long
* There's two `ff`. Does one of them color be the `255` (`0xff`) I set for the red channel, if there's a red channel ? Simple test : what if I switch color to `-red=255, --green=127, --blue=64` ? If I'm guessing right, Luxafor should sniff these hexadecimal values

{% highlight R %}
ff 7f 40
{% endhighlight %}

Let's try :

{% highlight bash %}
$ sudo ./luxafor color --red=255 --green=127 --blue=64
{% endhighlight %}

Guess what :

![Sniff again]({{ site.url }}/assets/2017-03-25/wireshark-sniff-2.png)

{% highlight R %}
01 ff ff 7f 40 00 00
{% endhighlight %}

* third byte is for the red channel
* fourth byte is for the green channel
* fifth byte is for the red channel

I still don't know what other bytes are for.

## Unload usbmon Kernel module

To clore your monitoring session in a clean way,, unload the __usbmod__ module :

{% highlight bash %}
$ sudo modprobe -r usbmon
{% endhighlight %}

# Write the client

In this chapter, we'll write a __[Vala](https://wiki.gnome.org/Projects/Vala)__ program that will try to change the __Luxafor__ color.

If you want to fully understand the next, let me suggesting to read chunks of documentation from [LibUSB](http://libusb.info/). It's what I did, and I learnt that prior to connect to an USB device, I have to find the __vendorID__ and __productID__ of the device.

## Find USB vendorID / productID

Capture with `lusb` command the list of connected device - with the Luxafor un-plugged, and re-fetch the list with the Luxafor plugged to guess which one is the device you're looking for :

{% highlight bash %}
$ lsusb > unplugged
# Plug your device
$ lsusb > plugged
# Don't remove any USB device a that time :p
$ diff plugged unplugged
1d0 < Bus 002 Device 008: ID 04d8:f372 Microchip Technology, Inc.
{% endhighlight %}

We've got the Luxafor device. `04d8:f372` are respectively the __vendorID__ and the __productID__ we're looking for.

## Write the client

### Install Vala and other dependencies

On an apt package manager based system, it's really straight forward :

{% highlight bash %}
$ sudo apt-get install vala libusb-1.0-0 libusb-1.0-0-dev libusb-dev
{% endhighlight %}

## Vala code

__main.vala__

{% highlight vala %}

int main(string[] args)
{
	LibUSB.Context context;
	LibUSB.Device[] devices;
	LibUSB.DeviceHandle handle;
	LibUSB.Device? luxafor = null;

	LibUSB.Context.init(out context);
	context.get_device_list (out devices);

	int i = 0;
	while (devices[i] != null)
	{
		var dev = devices[i];
		LibUSB.DeviceDescriptor desc = LibUSB.DeviceDescriptor (dev);
		if (desc.idVendor == 0x04d8 && desc.idProduct == 0xf372)
		{
			luxafor = dev;
			break;
		}
		i++;
	}		

	if (null != luxafor)
	{

		int result = luxafor.open(out handle);
		if (result != 0) {
			return 1;
		}

		handle.detach_kernel_driver(0);

		int retries = 1000;
		int claim_device_result;
		while ((claim_device_result = handle.claim_interface(0)) != 0 && retries-- > 0) {
			handle.detach_kernel_driver(0);
		}

		if (claim_device_result == 0)
		{
			int len;
			handle.bulk_transfer(1, {0x01, 0xff, 0xff, 0x7f, 0x40, 0x00, 0x00}, out len, 10);
		}
	}

	return 0;
}

{% endhighlight %}

### Compile and run

__Compile__

{% highlight bash %}
$ valac --pkg libusb-1.0 main.vala -o usb
{% endhighlight %}

__Run__

{% highlight bash %}
$ sudo ./usb
{% endhighlight %}

# And there is light !

__Luxafor__ start and the color change immediately to a bright color `--red=255 --green=127 --blue=64` - a bit ugly, I must say - but that was what I expected !

Thanks for reading, any feedbacks or contributions via [issues](https://github.com/lcallarec/lcallarec.github.io/issues) or [pull requests](https://github.com/lcallarec/lcallarec.github.io/pulls) are welcome !
