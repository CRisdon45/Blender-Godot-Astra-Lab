# Dab hierarchy soft-diffuse comparison

This is a renderer-only visual experiment on the approved public worker. It extends the retained three-band hierarchy-value dab tree and changes only direct diffuse response on the existing foliage materials.

Geometry, group transforms, hierarchy values, source tree data, palette inputs, water, paving, cameras and real shadow attenuation remain fixed. The custom light function deliberately compresses normal-driven face contrast but still multiplies scene ATTENUATION. It is not unlit foliage, a crown-normal replacement, alpha foliage, physical subsurface scattering, or a reproduction of the implicit-density paper.

The probe compares Lambert and compressed diffuse in Plan, courtyard, front, reverse and top views, verifies exact Lambert and morning returns, preserves material identities, geometry/transforms and source data, and confirms the hierarchy values do not change. Visual acceptance and tablet performance remain separate.
