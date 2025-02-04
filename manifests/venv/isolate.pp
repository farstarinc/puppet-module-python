define python::venv::isolate($ensure=present,
                             $version=latest,
                             $requirements=undef) {
  $root = $name
  $owner = $python::venv::owner
  $group = $python::venv::group
  $python = $python::dev::python

  if $ensure == 'present' {
    Exec {
      user => $owner,
      group => $group,
      cwd => "/tmp",
      logoutput => on_failure,
    }
  
    $parent_dir = regsubst($root, '^(.+)/.+/?$', '\1')
  
    if !defined(File[$parent_dir]) {
      file { $parent_dir:
        ensure => directory,
        owner => $owner,
        group => $group,
      }
    }

    # Does not successfully run as www-data on Debian:
    exec { "python::venv $root":
      command => "virtualenv --no-site-packages -p `which ${python}` ${root}",
      creates => $root,
      notify => Exec["update distribute and pip in $root"],
      require => [File[$parent_dir], Package["python-virtualenv"]],
    }
    ->
    # ensure correct permissions on created virtualenv
    file { $root:
      ensure => directory,
      owner => $owner,
      group => $group,
      mode => 775,
    } 

    # Some newer Python packages require an updated distribute
    # from the one that is in repos on most systems:
    exec { "update distribute and pip in $root":
      command => "$root/bin/pip install -U distribute pip",
      refreshonly => true,
    }

    if $requirements {
      python::pip::requirements { $requirements:
        venv => $root,
        owner => $owner,
        group => $group,
        require => Exec["python::venv $root"],
      }
    }

  } elsif $ensure == 'absent' {

    file { $root:
      ensure => $ensure,
      owner => $owner,
      group => $group,
      recurse => true,
      purge => true,
      force => true,
    }
  }
}
