// Dependencies
import { RalixApp } from 'ralix'
import "@hotwired/turbo-rails"
import "trix"
import "@rails/actiontext"

import "chartkick"

//= require jquery
//= require jquery_ujs
//= require_tree .
//= require turbolinks

//= require highcharts/highcharts
//= require highcharts/highcharts-more
//= require highcharts/highstock

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
