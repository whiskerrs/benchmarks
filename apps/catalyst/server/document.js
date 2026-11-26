import React from "react"
import { Head, Body } from "catalyst-core"

function Document(props) {
    return (
        <html lang="en">
            <Head {...props}>
                {/* Overrides Catalyst's default viewport: full-bleed under the safe areas, no zoom. */}
                <meta
                    name="viewport"
                    content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover"
                />
                <meta name="format-detection" content="telephone=no" />
                <title>Everbloom</title>
            </Head>
            <Body {...props} />
        </html>
    )
}
export default Document
