import { split } from "catalyst-core"

// split() lets Catalyst find the route's clientFetcher (Home's data).
const Shell = split(() => import("@containers/Shell/Shell"))

const routes = [
    {
        path: "/",
        component: Shell,
    },
]

export default routes
