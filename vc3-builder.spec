Name: vc3-builder
Version: 1.0.0
Release: 1%{?dist}
Summary: Pilot and software installer

License: MIT
URL: https://github.com/vc3-project/vc3-builder

AutoReqProv: no

# tarball generation:
# ------------------- 
# cd ~/rpmbuild/SOURCES
# git clone --depth=1 https://github.com/vc3-project/vc3-builder
# rm -rf vc3-builder/.git*
# tar -cvzf vc3-builder-1.0.0-src.tgz vc3-builder
Source0: vc3-builder-1.0.0-src.tgz

BuildArch: noarch
# Requires: 

BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
Prefix: %{_prefix}

%description


%prep
%setup -q -n vc3-builder
make clean

%build
make

%install
mkdir -p %{buildroot}/%{_bindir}
cp vc3-builder %{buildroot}/%{_bindir}

%files -n vc3-builder
%{_bindir}/vc3-builder

%changelog
* Wed Jan 17 2018 Lincoln Bryant <lincolnb@uchicago.edu> - 1.0.0-1
- Initial package
