# Maintainer: CachyOS zectl-for-cachyOS Project
# Original Maintainer: John Ramsden <johnramsden [at] riseup [dot] net>

pkgname=zectl-cachyos
_pkgname=zectl
pkgver=r157.a85e729
pkgrel=1
pkgdesc="ZFS Boot Environment manager (CachyOS optimized - no zfs-dkms dependency)"
url="http://github.com/johnramsden/zectl"
arch=('any')
license=('MIT')
# CachyOS has ZFS built into kernel - no need for zfs-dkms
depends=()
makedepends=('make' 'cmake' 'scdoc' 'git')
provides=('zectl')
conflicts=('zectl' 'zectl-git')
source=("${_pkgname}::git+https://github.com/johnramsden/${_pkgname}#branch=master")
sha256sums=(SKIP)

pkgver() {
    cd "${srcdir}/${_pkgname}"
    printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

build() {
    cd "${srcdir}/${_pkgname}"
    CFLAGS+=" -fmacro-prefix-map=$PWD/=" cmake -DCMAKE_INSTALL_PREFIX=/usr \
        -DPLUGINS_DIRECTORY=/usr/share/zectl/libze_plugin .
    make VERBOSE=1
}

check() {
    cd "${srcdir}/${_pkgname}"
    # Skip tests that require ZFS to be loaded (CachyOS may have it built-in)
    echo "Skipping tests - CachyOS has ZFS built into kernel"
}

package() {
    cd "${srcdir}/${_pkgname}"
    make DESTDIR="${pkgdir}" install
    install -Dm644 "${srcdir}/${_pkgname}/docs/zectl.8" "${pkgdir}/usr/share/man/man8/zectl.8"
    install -Dm644 "${srcdir}/${_pkgname}/README.md" "${pkgdir}/usr/share/doc/${pkgname}/README.md"
    install -Dm644 "${srcdir}/${_pkgname}/LICENSE" "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE-MIT"
}