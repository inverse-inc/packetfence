
package multi_domain_constants;
our (%ConfigRealm, @ConfigOrderedRealm, %ConfigDomain);
%ConfigRealm = (
                 'default' => {
                                'admin_strip_username' => 'disabled',
                                'eap' => 'default',
                                'portal_strip_username' => 'disabled',
                                'radius_strip_username' => 'disabled'
                              },
                 'local' => {
                              'admin_strip_username' => 'disabled',
                              'eap' => 'default',
                              'radius_strip_username' => 'disabled',
                              'portal_strip_username' => 'disabled'
                            },
                 'null' => {
                             'radius_strip_username' => 'disabled',
                             'portal_strip_username' => 'disabled',
                             'admin_strip_username' => 'disabled',
                             'eap' => 'default'
                           }
               );
@ConfigOrderedRealm = (
                        'default',
                        'local',
                        'null'
                      );
%ConfigDomain = ();
1;
