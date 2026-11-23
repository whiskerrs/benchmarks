import React from "react"
import { Outlet } from "react-router"

// Catalyst's app-level container. The app itself is the "/" route (Shell).
const App = () => <Outlet />

App.serverSideFunction = () => Promise.resolve()

export default App
