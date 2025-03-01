*! Ver 1.00 22.11.2021


*************************
*					    *
*       Voronoi         *
*         by            *
*     Asjad Naqvi		*
*                       * 
*     Last updated:     *
*      2 Dec 2021       *
*						* 
*************************



cap program drop voronoi

program define voronoi
	version 15
	
	di "Voronoi: Initializing"
	mata: voronoi_core(triangles, points, coords, halfedges, hull)
	di "Voronoi: Done with Mata routines"
	
	// push to Stata
	svmat vor
	mat colnames vor = "vor_x1" "vor_y1" "vor_x2" "vor_y2"
	cap drop vor* 
	svmat vor, n(col)
	di "Voronoi: Done with export to Stata"
	
end	

************************
// 	   voronoi_core	  //		
************************


cap mata: mata drop voronoi_core()

mata // voronoi_core
function voronoi_core(triangles, points, coords, halfedges, hull)
{

	triangles = select(triangles, (triangles[.,1] :< .)) // added 17.12.2021
	tri3 = colshape(triangles',3)'  // reshape triangles
	
	xmin = .
	xmax = .
	ymin = .
	ymax = .
	
	bounds(points,xmin,xmax,ymin,ymax) 
	
	// collect the voronoi centers in vector renamed from triangleCenter to vorcenter
	num2 = rows(triangles) / 3  // drop the missing rows


	vorcenter = J(num2,2,.)
	for (i=1; i <= num2; i++) {
		vorcenter[i,.]  = circumcenter2(points,triangles,i)
	}
	
	
	voredges = J(rows(triangles),2,.)  // voronoi edge pairs indexed to vorcenter
	forEachVoronoiEdge(triangles,halfedges,voredges)
	voredges = select(voredges, (voredges[.,1] :< .)) // drop the missing rows

	
	// coordinates of the interior points
	
	point0 = J(rows(triangles),2,.)
	point1 = J(rows(triangles),2,.)

			for (i=1; i <= rows(triangles); i++) {
				if (i < halfedges[i]) {
					point0[i,.] = vorcenter[triangleOfEdge(i),.]
					point1[i,.] = vorcenter[triangleOfEdge(halfedges[i]),.]
				}
			}

			
	point0 = select(point0, (point0[.,1] :< .)) // drop the missing rows
	point1 = select(point1, (point1[.,1] :< .)) // drop the missing rows		

	
	// exterior cell rays
	
	hlen = hull[rows(hull), 1]
	
	p0 = hlen * 4
	p1 = hlen * 4
	
	x0 = coords[2 * hlen - 1, 1]
	x1 = coords[2 * hlen - 1, 1]
	
	y0 = coords[2 * hlen, 1]
	y1 = coords[2 * hlen, 1]
	
	vectors = J(rows(triangles) * 2, 1, 0)

	
	
		for (i=1; i<=rows(hull); i++) {			
			
			hme = hull[i,1]
			
			p0 = p1
			x0 = x1
			y0 = y1
			
			p1 = hme * 4
			
			x1 = coords[2 * hme - 1, 1]		
			y1 = coords[2 * hme    , 1]
			
			vectors[p0 + 2, 1] = y0 - y1
			vectors[p1 - 0, 1] = y0 - y1
			
			vectors[p0 + 3, 1] = x1 - x0
			vectors[p1 + 1, 1] = x1 - x0			
		}	
		

	// add the boundary edges
	pointh0 = J(rows(hull),2,.)
	pointh1 = J(rows(hull),2,.)
			
	h0 = hull[rows(hull),1]
	h1 = hull[rows(hull),1]

		
		for (i=1; i <= rows(hull); i++) {
			
			h0 = h1
			h1 = hull[i,1]
			t = findhulltri(h0,h1,tri3)
			
			xxx  = vorcenter[t,.] 
			
			v = h0 * 4
			p = project(xxx[1,1], xxx[1,2], vectors[v + 2, 1], vectors[v + 3, 1], xmin, xmax, ymin, ymax)
			
			if (p[1,1] > 0) {
			pointh0[i,.] = vorcenter[t,.]
			pointh1[i,.] = p
			}
		}
		

	
	// append with point type
	point0 =  point0 \ pointh0
	point1 =  (point1, J(rows(point1),1,1)) \ (pointh1, J(rows(pointh1),1,2))
	
	
	cliplist = J(rows(point0),4,.)
		for (i=1; i <= rows(point0); i++) {			
			//i
			cliplist[i,.] = clipline(point0[i,1], point0[i,2], point1[i,1], point1[i,2], xmin, xmax, ymin, ymax)	

		}

	cliplist = select(cliplist, (cliplist[.,2] :< .)) // drop the missing rows	
	
	st_matrix("vor",cliplist)
	
}

end







////////////////////////////////////
///   voronoi subroutines here   ///
////////////////////////////////////

********************
// 	   bounds	  //		
********************

cap mata: mata drop bounds()

mata // bounds
function bounds(points,xmin,xmax,ymin,ymax)
{

	displacex = (max(points[.,1]) - min(points[.,1])) * 0.05
	displacey = (max(points[.,2]) - min(points[.,2])) * 0.05

	xmin 	  = floor(min(points[.,1])) - displacex
	xmax 	  =  ceil(max(points[.,1])) + displacex

	ymin 	  = floor(min(points[.,2])) - displacey
	ymax 	  =  ceil(max(points[.,2])) + displacey

	st_numscalar("xmin", xmin)
	st_numscalar("xmax", xmax)

	st_numscalar("ymin", ymin)
	st_numscalar("ymax", ymax)
	
}
end


************************
// 	 triangleOfEdge   //     // index
************************

cap mata: mata drop triangleOfEdge()
mata: // triangleOfEdge
function triangleOfEdge(x)
	{
		return(floor((x - 1) / 3) + 1)
	}
end


************************
// 	 edgesOfTriangle  //    
************************

cap mata: mata drop edgesOfTriangle()
mata: // edgesOfTriangle
function edgesOfTriangle(t)
	{
		return (3 * t - 2, 3 * t - 1, 3 * t)
	}
end

***************************
// 	 pointsOfTriangle    // 
***************************

cap mata: mata drop pointsOfTriangle()
mata:  // pointsOfTriangle
function pointsOfTriangle(triangles,t)
	{
		return(triangles[edgesOfTriangle(t)[1,1],1],triangles[edgesOfTriangle(t)[1,2],1],triangles[edgesOfTriangle(t)[1,3],1] )
	}
end

// another circumcenter. it just returns a different structure

************************
// 	  circumcenter2	  //	
************************    

cap mata: mata drop circumcenter2()

mata: // circumcenter2
function circumcenter2(points,triangles,i)
{
	real matrix myset
	real scalar t1, t2, t3
	
	myset = points[pointsOfTriangle(triangles,i),.]
		
	x1 = myset[1,1]
	y1 = myset[1,2]
	x2 = myset[2,1]
	y2 = myset[2,2]
	x3 = myset[3,1]
	y3 = myset[3,2]
	
	
	dx = x2 - x1
	dy = y2 - y1
	ex = x3 - x1
	ey = y3 - y1
	ab = (dx * ey - dy * ex) * 2
	
	
	if (abs(ab) < 1e-9 ) {
		// degenerate case 
	
		a = 1e9
		r = triangles[1] * 2
		a = a * sign((points[r - 1,1] - x1) * ey - (points[r,1] - y1) * ex);
		myx = (x1 + x3) / 2 - a * ey;
		myy = (y1 + y3) / 2 + a * ex;
		
	}
	else {	
	    d = 1 / ab;
        bl = dx * dx + dy * dy;
        cl = ex * ex + ey * ey;
        myx = x1 + (ey * bl - dy * cl) * d;
        myy = y1 + (dx * cl - ex * bl) * d;	
	}
	
	return(myx,myy)
}
end



**************************
// 	 Voronoi edges      // the triangle center pairs that need to be connected
**************************


cap mata: mata drop forEachVoronoiEdge()

mata: // forEachVoronoiEdge
function forEachVoronoiEdge(triangles,halfedges, real matrix xx) 
	{
		for (i=1; i <= rows(triangles); i++) {
			if (i < halfedges[i]) {
				
				xx[i,.] = triangleOfEdge(i), triangleOfEdge(halfedges[i])

			}
		}
			
	}
end

************************
// 	  _project		  //
************************    

cap mata: mata drop project()

mata: // project
function project(x0, y0, vx, vy, xmin, xmax, ymin, ymax)
{
	real scalar t, c
	t = .   // just a very large number
	
	if (vy < 0) { // top
		
		if (y0 <= ymin) return(0,0)
		
		
		c = (ymin - y0) / vy
		if (c < t) {
			myy = ymin
			myx = x0 + (t = c) * vx
		}
    } 

	else { // bottom
	
		if (y0 >= ymax) return(0,0)
		
		
		c = (ymax - y0) / vy
		if (c < t) {
			myy = ymax
			
			myx = x0 + (t = c) * vx
		}
	}
    
	if (vx > 0) { // right
		
		if (x0 >= xmax) return(0,0)
		
		c = (xmax - x0) / vx
		if (c < t) {
			myx = xmax
			myy = y0 + (t = c) * vy
		}
    } 
	
	else { // left
		if (x0 <= xmin) return(0,0)
		
		c = (xmin - x0) / vx
		if (c < t) {
			myx = xmin
			myy = y0 + (t = c) * vy
		}
    }
	
	return(myx, myy)
	
}
end



************************
// 	  find hull tri	  //	
************************

cap mata: mata drop findhulltri()

mata: //  find hull tri whose circumcenter we need
function findhulltri(x,y,tri3)
{	
	for (i=1; i <= cols(tri3); i++) {	
		if (max(x:==tri3[.,i])==1 & max(y:==tri3[.,i])==1)	return(i)
	}
}
end


			

*********************
// 	   clipline    //
*********************




cap mata: mata drop clipline()
mata:  // clipline
	function clipline(x1, y1, x2, y2, minX, maxX, minY, maxY)  
	{
		real scalar code1, code2, accept, x, y

		// Defining region codes 
		LEFT   = 1  // 0001 
		RIGHT  = 2  // 0010 
		BOTTOM = 4  // 0100 
		TOP    = 8  // 1000 
		
		
		code1 = computeCode(x1, y1, minX, maxX, minY, maxY)
		code2 = computeCode(x2, y2, minX, maxX, minY, maxY)
		
		//code1, code2, code1 & code2
		
		accept = 0
		
		t = 0 // counter
		
		zz = 0
		while (zz == 0)  {
		
		//t
		
			// If both endpoints lie within rectangle 
			if (code1 == 0 & code2 == 0) {
				accept = 1
				break
			}
			// If both endpoints are outside rectangle 
			else if (code1==code2 & code1!=0 & code2!=0) {
				accept = 0
				
				x1 = .
				y1 = .
				x2 = .
				y2 = .
				
				break
			}
			
			// Some segment lies within the rectangle 			
			else {	
				x = 1
				y = 1
				
				if (code1 != 0) {
					codeout = code1
				}
				else {
					codeout = code2
				}
				
				// point is above the clip rectangle 
				if (codeout >= TOP) {   					// fix this line. what is top?
					x = x1 + ((x2 - x1) * (maxY - y1) / (y2 - y1))
					y = maxY
				}
				// point is below the clip rectangle
				else if (codeout >= BOTTOM) {
					x = x1 + ((x2 - x1) * (minY - y1) / (y2 - y1))
					y = minY
				}
				// point is to the right of the clip rectangle 
				else if (codeout >= RIGHT) {
					y = y1 + ((y2 - y1) * (maxX - x1) / (x2 - x1))
					x = maxX
				}
				// point is to the left of the clip rectangle 
				else if (codeout >= LEFT) {
					y = y1 + ((y2 - y1) * (minX - x1) / (x2 - x1))
					x = minX
				}	
				
			if (codeout == code1) { 
                x1 = x 
                y1 = y 
                code1 = computeCode(x1, y1, minX, maxX, minY, maxY) 
			}
			else {
                x2 = x 
                y2 = y 
                code2 = computeCode(x2, y2, minX, maxX, minY, maxY) 
			}
		
		t = t + 1
		if (t > 100) {
			printf("bad egg\n")
				x1 = .
				y1 = .
				x2 = .
				y2 = .
			break
			}
		
		}

	}
	
			
	return(x1,y1,x2,y2)
}
end




*********************
// 	 computeCode   //
*********************


cap mata: mata drop computeCode()
mata // computeCode
	function computeCode(xx, yy, minX, maxX, minY, maxY)  // triangleCenter,
	{
		real scalar code
		code = 0   // 1 = left, 2 = right, 4 = bottom, 8 = top (defined in binary)
			if (xx < minX) code = code + 1
			if (xx > maxX) code = code + 2		
			if (yy < minY) code = code + 4
			if (yy > maxY) code = code + 8	
		return(code)
	}
end



**** END OF CLIPLINE ****

