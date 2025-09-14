// Dependencies
import { RalixApp } from 'ralix'
import "@hotwired/turbo-rails"
import "trix"
import "@rails/actiontext"


// app/javascript/application.js
import "chartkick"
import "chart.js" // Corrected import



// Controllers
import AppCtrl      from './controllers/app'
import ArticlesCtrl from './controllers/articles'

// Components
import RemoteModal  from './components/remote_modal'
import Tooltip      from './components/tooltip'

import "./good_job_custom.js";


const App = new RalixApp({
  routes: {
    '/articles$': ArticlesCtrl,
    '/.*': AppCtrl
  },
  components: [
    RemoteModal,
    Tooltip
  ]
})

App.start()
