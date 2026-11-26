import { useCallback, useEffect, useRef, useState } from "react"
import { gql } from "../api/graphql"

/** One-shot query keyed by its variables; `retry` repeats the request. */
export function useQuery(operationName, variables) {
    const key = JSON.stringify(variables)
    const [state, setState] = useState({ data: null, error: null })
    const generation = useRef(0)

    const run = useCallback(() => {
        const gen = ++generation.current
        setState({ data: null, error: null })
        gql(operationName, JSON.parse(key)).then(
            (data) => gen === generation.current && setState({ data, error: null }),
            (error) => gen === generation.current && setState({ data: null, error })
        )
    }, [operationName, key])

    useEffect(run, [run])

    return { ...state, retry: run }
}
