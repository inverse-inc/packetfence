    <!-- Le javascript
    ================================================== -->
    <!-- Placed at the end of the document so the pages load faster -->
    <script src="[% c.uri_for('/static/app/jquery.js') %]"></script>
    <script src="[% c.uri_for('/static/js/bootstrap.js') %]"></script>
    <script src="[% c.uri_for('/static/app/application.js') %]"></script>
    [% FOREACH js = jsFiles %]<script src="[% c.uri_for("/static/app/${js}.js") %]"></script>[% END %]

  </body>
</html>
