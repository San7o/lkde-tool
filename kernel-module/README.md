# kernel-module

Sample out-of-tree linux kernel module.

## Usage

Run the following commands from the lkde root tree. To build the
module:

```bash
make module
```

Clean the build:

```bash
make module-clean
```

To load the image:

```bash
make module-load
```

Inside the image, you will find the module in the /root directory. You
can load it with `insmod`

```bash
insmod ./hello.ko
```

Check messages in `dmeg`:

```bash
dmesg
```

List loaded modules:

```bash
lsmod | grep hello
```

Remove it with:

```bash
rmmod -f hello
```
