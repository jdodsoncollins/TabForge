/** Remove only the plain, edge-connected white Simulator window outside a chassis.
 * A closed dark chassis bounds every display. Interior pixels remain unchanged.
 */
export async function deviceCutout(sharp, source, crop) {
  const {data,info}=await sharp(source).extract({left:crop.x??crop.left,top:crop.y??crop.top,width:crop.width,height:crop.height}).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  const n=info.width*info.height, outside=new Uint8Array(n),queue=new Int32Array(n);let head=0,tail=0;
  const white=i=>{const p=i*4;return Math.min(data[p],data[p+1],data[p+2])>=250&&Math.max(data[p],data[p+1],data[p+2])-Math.min(data[p],data[p+1],data[p+2])<=2;};
  const add=i=>{if(!outside[i]&&white(i)){outside[i]=1;queue[tail++]=i;}};
  for(let x=0;x<info.width;x++){add(x);add((info.height-1)*info.width+x);}for(let y=0;y<info.height;y++){add(y*info.width);add(y*info.width+info.width-1);}
  while(head<tail){const i=queue[head++],x=i%info.width,y=Math.floor(i/info.width);if(x)add(i-1);if(x+1<info.width)add(i+1);if(y)add(i-info.width);if(y+1<info.height)add(i+info.width);}
  if(tail/n>.55)throw new Error('Exterior mask unexpectedly reached more than half the device crop.');
  // Retain the one-pixel antialias transition at the dark outer edge. Its original
  // white matte is converted to alpha, leaving every opaque interior byte alone.
  const fringe=new Set();for(let q=0;q<tail;q++){const i=queue[q],x=i%info.width,y=Math.floor(i/info.width);for(const j of[x?i-1:-1,x+1<info.width?i+1:-1,y?i-info.width:-1,y+1<info.height?i+info.width:-1])if(j>=0&&!outside[j])fringe.add(j);data[i*4+3]=0;}
  for(const i of fringe){const p=i*4,low=Math.min(data[p],data[p+1],data[p+2]),high=Math.max(data[p],data[p+1],data[p+2]);if(low>=150&&high-low<=3){data[p]=data[p+1]=data[p+2]=0;data[p+3]=255-low;}}
  return {buffer:await sharp(data,{raw:{width:info.width,height:info.height,channels:4}}).png().toBuffer(),width:info.width,height:info.height,removedExteriorPixels:tail,antialiasCandidates:fringe.size};
}
