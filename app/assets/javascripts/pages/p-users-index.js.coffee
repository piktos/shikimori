@on 'page:load', 'users_index', ->
  # если страница ещё не готова, перегрузимся через 5 секунд
  if $('p.pending').exists()
    Turbolinks.visit.delay 5000, location.href, true
